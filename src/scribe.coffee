
ipfsApi = require 'ipfs-api'
fs = require 'fs'
path = require 'path'
mkdirp = require 'mkdirp'
web3 = require './lib/web3'
child_process = require 'child_process'
exec = child_process.exec
spawn = child_process.spawn
coffee = require 'coffee-script'
less = require 'less'

httpServer = require 'http-server'


CONTENT_CHANNEL = '/content'
CONTENT_PATH = '/var/data/content'
WHISPER_ID = undefined

ETH_HOST = process.env.ETH_PORT_8545_TCP_ADDR or 'localhost'
ETH_PORT = process.env.ETH_PORT_8545_TCP_PORT or 8545

IPFS_HOST = process.env.IPFS_PORT_5001_TCP_ADDR or 'localhost'
IPFS_PORT = process.env.IPFS_PORT_5001_TCP_PORT or 5001

console.log "Compiling assets..."
assetPath = path.join( CONTENT_PATH, './assets' )

exec "coffee -c #{ path.join( assetPath, './js/content.coffee' ) }", (err,stdout,stderr) ->
    console.log err if err
    console.log "Compiled coffeescript" unless err

    exec "lessc #{ path.join( assetPath, './css/content.less' ) } > #{ path.join( assetPath, './css/content.css' ) }", (err,stdout,stderr) ->
        console.log err if err
        console.log "Compiled less" unless err


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
                    console.log "Unable to construct invalid post: " + @validationError( msg )
                    @error = true


            validationError: (msg) ->
                return @error unless msg
                return "Needs a payload" unless msg.payload
                return "Needs an author" unless msg.from and msg.from != '0x0'
                return "Needs a title or parent" unless msg.payload.title or msg.payload.parent
                return "Must not have both title and parent" if msg.payload.title and msg.payload.parent
                return "Needs a link or content" unless msg.payload.link or msg.payload.content
                return "Must not have both link and content" if msg.payload.link and msg.payload.content

            persist: ->
                if @validationError()
                    console.log "Unable to persist invalid post"
                    console.log @
                    return

                contentBuffer = new Buffer( @link or @content )
                titleBuffer = new Buffer( @title ) if @title


                ipfs.add [ contentBuffer ], (err,files) =>
                    if @parent
                        pathName = path.join( CONTENT_PATH, 'posts', @parent, files[0].Hash )
                    else
                        pathName = path.join( CONTENT_PATH, 'posts', files[0].Hash )
                        # Early out if this hash exists already.
                        return if fs.existsSync( pathName )
                    
                    mkdirp pathName, (err) ->
                        throw err if err
                        console.log "made new post folder"
                        
                        fs.writeFile path.join( pathName, './content' ), contentBuffer, (err) ->
                            throw err if err
                            console.log "written content"
                            if @title
                                fs.writeFile path.join( pathName, './title' ), titleBuffer, (err) ->
                                    throw err if err
                                    console.log "written title"
                                    updateContent()
                            else
                                updateContent()


        # class Comment extends Post
        #     validationError: (msg) ->
        #         return @valid unless msg
        #         return false unless msg.payload
        #         return false unless msg.from and msg.from != '0x0'
        #         return false unless msg.payload.parent
        #         return false unless msg.payload.content


        updateContent = ->
            postsPath = path.join( CONTENT_PATH, './posts' )
            postsRaw = fs.readdirSync( postsPath )
            posts = postsRaw.filter (p) -> p != 'index.json'
            fs.writeFileSync( path.join( postsPath, './index.json') , JSON.stringify( posts ) )
            console.log( "Updated posts index.json (#{ posts.length })" )

            cmd = "ipfs add -r #{ CONTENT_PATH }"
            console.log "IFPS: #{ cmd }"
            exec cmd, (err,stdout,stderr) ->
                console.log err if err
                console.log( "IPFS: ipfs add result:", stdout )
                hashes = stdout.split('\n').map (line) -> line.split(' ')[1]
                roothash = hashes[hashes.length - 2]

                if roothash != recenthash
                    console.log "IPFS: New roothash: #{ roothash }"

                    if WHISPER_ID
                        recenthash = roothash
                        tmp = web3.shh.post
                            from: WHISPER_ID
                            topics: [CONTENT_CHANNEL]
                            payload: JSON.stringify( root: roothash )
                        console.log "Published new rootHash: #{ roothash } to Whisper channel"
                        fs.writeFileSync( path.join( __dirname, '../public/ipfslink.html') , "/content: <a href='http://gateway.ipfs.io/ipfs/#{ roothash }'>Read Only Demo</a>" )
                    else
                        console.log "Not published to Whisper"

        cmd = "ipfs id < /dev/tty"
        console.log "IFPS: #{ cmd }"
        exec cmd, (err, stdout, stderr) ->
            console.log err if err
            info = JSON.parse( stdout )
            console.log "IPFS id: ", info.ID
            console.log "IPFS path: ", CONTENT_PATH

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

                
                    staticPath = path.join( __dirname, '../public' )
                    staticServer = httpServer.createServer
                        root: staticPath
                        cache: 10
                        showDir: false
                        autoIndex: false
                        robots: false
                        ext: null
                        logFn: null
                        proxy: false
                        cors: true

                    staticServer.listen 6002, '0.0.0.0', ->
                        console.log "Running static server for #{ staticPath } at 0.0.0.0:6002 "

                        
