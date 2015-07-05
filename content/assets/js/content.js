$(function(){

	CONTENT_CHANNEL = '/content'
	console.log("content init")

	web3.setProvider( new web3.providers.HttpProvider() )
	identity = web3.shh.newIdentity()
	messageFilter = web3.shh.filter( { topics: [CONTENT_CHANNEL] } )

	$( "#content" ).load( 'posts' );

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
			$( "#content" ).load( '/ipfs/' + msg.payload.root + '/posts' );
		} 
	})
})