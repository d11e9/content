$ ->

    CONTENT_CHANNEL = '/content'
    $content = $ '#content'
    ethHost = 'localhost'
    ethPort = 8545

    console.log("content init")

    refreshPosts = (newRoot) ->
        path = 'posts/'
        if newRoot
            path = '/ipfs/' + newRoot + '/' + path

        $.getJSON path + 'index.json', (posts, status, xhr) ->
            $('#content .loading').remove()
            console.log( "Loaded posts:", posts )
            posts.map (post, index) ->
                $el = $("##{ post }")
                $content.append( buildPost( path, post, index, $el ) )

    buildPost = ( path, post, index, $el ) ->
        $post = if $el.length
            $el
        else
            $( $('#post-template').html() )

        $post.attr( 'data-index', index )
        $post.attr( 'id', post )

        getContent path + post + '/title', ( err, title) ->
            $post.find( '.title' ).html( title )

        # link
        getContent path + post + '/content', ( err, content) ->
            isHttp = /^https?:\/\//
            if isHttp.test( content )
                $post.find( '.content' ).attr( 'href',  content )
            else
                $post.find( '.content' ).attr( 'href',  '/ipfs/' + post )

        getContent path + post + '/index.json', ( err, comments) ->
            $post.find( '.comment-count' ).html( comments.length )
            $post.find( '.comment' ).attr( 'href', post )

        $post unless $el.length

    getContent = (url, cb) ->
        $.get url, (responseText, status, xhr) ->
            cb( !responseText, responseText )



    config = null
    $config = $('<div id="content-config"/>')
    $config.load 'config', ->
        console.log("Config request response: ", arguments )
        try
            config = JSON.parse( $config.text() )
            if config.defaults
                ethHost = config.defaults.eth_host
                ethPort = config.defaults.eth_port
                CONTENT_CHANNEL = config.defaults.shh_channel
                $('#ipfs-status').addClass('connected')
        catch err
            console.log( "Unable to parse config" )


        web3.setProvider( new web3.providers.HttpProvider( "http://" + ethHost + ":" + ethPort ) )
        try
            identity = web3.shh.newIdentity()
            messageFilter = web3.shh.filter( { topics: [CONTENT_CHANNEL] } )
            $('#eth-status').addClass('connected')

            messageFilter.watch (err,msg) ->
                if !err and msg
                    console.log( "Message: ",  JSON.stringify( msg ) )
                if !err and msg?.payload?.root
                    console.log( "Received root hash update: ", msg )
                    refreshPosts( msg.payload.root )
        catch err
            console.log err

        refreshPosts( null )

        $('#createPost').click ->
            $('#postContent').html( $("#postContent-template").html() )
            $('#postContent .submit').click ->

                content = $('#postContent .content').val()
                title = $('#postContent .title').val()

                web3.shh.post
                    from: identity
                    topics: [CONTENT_CHANNEL]
                    payload: JSON.stringify
                        from: identity
                        content: content
                        title: title

                console.log( "posted content to whisper channel" )
                $('#postContent').empty()

        $(document.body).on 'click', '.post a', (ev) ->
            ev.preventDefault()
            $el = $(this)
            $post = $el.closest('.post')
            
            if $el.hasClass('comment')
                web3.shh.post
                    from: identity
                    topics: [CONTENT_CHANNEL]
                    payload: JSON.stringify
                        from: identity
                        parent: $post.attr( 'id' )
                        content: "A comment!!"

            console.log( $el )
            false
