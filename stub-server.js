var express = require('express');
var app = express();

var current_response;
var counter = 0;

app.get('/events/', function (req, res) {
	req.socket.setTimeout(Number.MAX_VALUE);
	res.writeHead(200, {
		'Content-Type': 'text/event-stream',
		'Cache-Control': 'no-cache',
		'Connection': 'keep-alive'
	});
    res.write('\n');
    current_response = res;
})

setInterval(function () {
    if(current_response) {
	    current_response.write("data: " + ++counter + "\n");
	    current_response.write("data: " + ++counter + "\n\n");
    }
}, 2000);

app.listen(process.env.PORT || 8080);
