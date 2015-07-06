$(function(){

    var CONTENT_CHANNEL = '/content';
    var $content = $('#content');
    var ethHost = 'localhost';
    var ethPort = 8545;

    console.log("content init")

    function refreshPosts( newRoot ) {
        var path = 'posts/';
        if (newRoot) path = '/ipfs/' + newRoot + '/' + path;

        $.getJSON( path + 'index.json', function(posts, status, xhr) {
            $content.empty();
            console.log( "Loaded posts:", posts )
            posts.map( function(post, index) {
                $content.append( $('<li data-index='+index+' id="'+post+'"/>').load( path + post + '/title' ) )
            });
        });
    }


    var config,$config = $('<div id="content-config"/>')
    $config.load( 'config', function(){
        console.log("Config request response: ", arguments )
        try {
            config = JSON.parse( $config.text() )
            if (config.defaults) {
                ethHost = config.defaults.eth_host;
                ethPort = config.defaults.eth_port;
                CONTENT_CHANNEL = config.defaults.shh_channel;
            }
        } catch(err) {
            console.log( "Unable to parse config" )
        }


        web3.setProvider( new web3.providers.HttpProvider( "http://" + ethHost + ":" + ethPort ) )
        var identity = web3.shh.newIdentity()
        var messageFilter = web3.shh.filter( { topics: [CONTENT_CHANNEL] } )

        refreshPosts( null )

        $('#createPost').click( function(){
            var content = prompt( "Enter post content: " )
            web3.shh.post({
                from: identity,
                topics: [CONTENT_CHANNEL],
                payload: JSON.stringify({
                    from: identity,
                    content: content,
                    title: 'untitled (for now)'
                })
            });

            console.log( "posted content to whisper channel" )
        })


        messageFilter.watch( function(err,msg){
            if (!err && msg) console.log( "Message: ",  JSON.stringify( msg ) );
            if (!err && msg && msg.payload && msg.payload.root) {
                console.log( "Received root hash update: ", msg )
                refreshPosts( msg.payload.root )
            } 
        })




    })
})
