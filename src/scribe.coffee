
ipfsApi = require 'ipfs-api'
fs = require 'fs'
path = require 'path'
mkdirp = require 'mkdirp'
web3 = require 'web3'
child_process = require 'child_process'
exec = child_process.exec
spawn = child_process.spawn

CONTENT_CHANNEL = '/content'
CONTENT_PATH = path.join __dirname, "../content"
WHISPER_ID = undefined

ETH_HOST = process.env.ETH_PORT_8545_TCP_ADDR
ETH_PORT = process.env.ETH_PORT_8545_TCP_PORT

IPFS_HOST = 'localhost' # process.env.IPFS_PORT_5001_TCP_ADDR
IPFS_PORT = 5001        #process.env.IPFS_PORT_5001_TCP_PORT


recenthash = null

console.log "Initializing /content scribe..."
console.log "Channel: #{ CONTENT_CHANNEL }"


ipfs = new ipfsApi( IPFS_HOST, IPFS_PORT )
httpProvider = new web3.providers.HttpProvider( "http://#{ ETH_HOST }:#{ ETH_PORT }" )

web3.setProvider( httpProvider )


console.log "Eth provider: #{ web3.currentProvider.host }"
console.log "IPFS provider: http://#{ IPFS_HOST }:#{ IPFS_PORT }"


class Post
    constructor: (msg) ->
        unless @validationError( msg )
            @author = msg.from
            @title = msg.payload.title or null
            @parent = msg.payload.parent or CONTENT_CHANNEL
            @content = msg.payload.content or null
            @link = msg.payload.link or null
            @error = false
        else
            console.log "Unable to construct invalid post", @validationError( msg )


    validationError: (msg) ->
        return @error unless msg
        return "Needs a payload" unless msg.payload
        return "Needs an author" unless msg.from and msg.from != '0x0'
        return "Needs a title" unless msg.payload.title
        return "Needs a link or content" unless msg.payload.link or msg.payload.content
        return "Must not have both link and content" if msg.payload.link and msg.payload.content

    persist: ->
        if @validationError()
            console.log "Unable to persist invalid post"
            console.log @
            return

        contentBuffer = new Buffer( @link or @content )
        titleBuffer = new Buffer( @title )

        ipfs.add [ contentBuffer ], (err,files) ->
            pathName = path.join( CONTENT_PATH, '/posts/', files[0].Hash )
            mkdirp pathName, (err) ->
                throw err if err
                console.log "made new post folder"
                fs.writeFile path.join( pathName, './content' ), contentBuffer, (err) ->
                    throw err if err
                    console.log "written content"
                    fs.writeFile path.join( pathName, './title' ), titleBuffer, (err) ->
                        throw err if err
                        console.log "written title"
                        updateContent()


# class Comment extends Post
#     validationError: (msg) ->
#         return @valid unless msg
#         return false unless msg.payload
#         return false unless msg.from and msg.from != '0x0'
#         return false unless msg.payload.parent
#         return false unless msg.payload.content


updateContent = ->
    ipfs.id (err, info) ->
        throw err if err

        unless recenthash
            console.log "IPFS id: ", info.ID
            console.log "IPFS path: ", CONTENT_PATH

        exec "ipfs add -r -q #{ CONTENT_PATH }", (err,stdout,stderr) ->
            console.log err if err
            hashes = stdout.split('\n')
            roothash = hashes[hashes.length - 2]

            if (WHISPER_ID and roothash != recenthash)
                recenthash = roothash
                tmp = web3.shh.post
                    from: WHISPER_ID
                    topics: [CONTENT_CHANNEL]
                    payload: JSON.stringify( root: roothash )
                console.log "Published new rootHash: #{ roothash } to Whisper channel"
            else
                console.log "Not published to Whisper"

web3.eth.getCoinbase (err,coinbase) ->
    throw err if err
    console.log "Eth coinbase: #{ coinbase }"

    web3.shh.newIdentity (err,shhid) ->
        throw err if err
        console.log "Whisper identity: #{ shhid }"
        WHISPER_ID = shhid
        updateContent()
    
        filter = web3.shh.filter( topics: [CONTENT_CHANNEL] )
        filter.watch (err, msg) ->
            # early out if message is from self
            return if msg?.from is shhid

            console.log "Whisper message received."
            if err
                console.log err
                return

            post = new Post(msg)
            post.persist()
                
