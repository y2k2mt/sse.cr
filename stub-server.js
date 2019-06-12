var express = require('express');
var app = express();

var current_response;
var all_response;
var counter = 0;
var id = 0;

app.get('/events/', function (req, res) {
	req.socket.setTimeout(2147483647);
	res.writeHead(200, {
		'Content-Type': 'text/event-stream',
		'Cache-Control': 'no-cache',
		'Connection': 'keep-alive'
	});
    res.write('\n');
    current_response = res;
})

app.get('/all/', function (req, res) {
	req.socket.setTimeout(2147483647);
	res.writeHead(200, {
		'Content-Type': 'text/event-stream',
		'Cache-Control': 'no-cache',
		'Connection': 'keep-alive'
	});
    res.write('\n');
    all_response = res;
})

app.get('/badrequest/', function (req, res) {
    res.status(400).end()
})

setInterval(function () {
    if(current_response) {
	    current_response.write("data: " + ++counter + "\n");
	    current_response.write("data: " + ++counter + "\n\n");
    }
}, 2000);

setInterval(function () {
    if(all_response) {
	    all_response.write("id: " + ++id + "\n");
	    all_response.write("retry: 2000\n");
	    all_response.write("event: usermessage\n");
	    all_response.write("data: foo\n");
	    all_response.write("data: bar\n\n");
    }
}, 2000);

app.listen(process.env.PORT || 8080);
