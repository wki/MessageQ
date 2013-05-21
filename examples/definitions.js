{
    "rabbit_version": "3.0.4",
    "parameters": [],
    "policies": [],
    "users": [{
        "name": "guest",
        "password_hash": "AsYO2ESs62RcsxNVyxKaR5DGxVI=",
        "tags": "administrator"
    }, {
        "name": "worker",
        "password_hash": "pyQyqKIF5yt0XLk6hStH2OQkYP4=",
        "tags": ""
    }],
    "vhosts": [{
        "name": "/"
    }],
    "permissions": [{
        "user": "guest",
        "vhost": "/",
        "configure": ".*",
        "write": ".*",
        "read": ".*"
    }, {
        "user": "worker",
        "vhost": "/",
        "configure": ".*",
        "write": ".*",
        "read": ".*"
    }],
    "queues": [{
        "name": "delay",
        "vhost": "/",
        "durable": true,
        "auto_delete": false,
        "arguments": {
            "x-message-ttl": 2000,
            "x-dead-letter-exchange": "render",
            "x-dead-letter-routing-key": "delayed.render"
        }
    }, {
        "name": "me-render",
        "vhost": "/",
        "durable": true,
        "auto_delete": false,
        "arguments": {}
    }, {
        "name": "render",
        "vhost": "/",
        "durable": true,
        "auto_delete": false,
        "arguments": {}
    }],
    "exchanges": [{
        "name": "render",
        "vhost": "/",
        "type": "topic",
        "durable": true,
        "auto_delete": false,
        "internal": false,
        "arguments": {}
    }, {
        "name": "delay",
        "vhost": "/",
        "type": "topic",
        "durable": true,
        "auto_delete": false,
        "internal": false,
        "arguments": {}
    }],
    "bindings": [{
        "source": "delay",
        "vhost": "/",
        "destination": "delay",
        "destination_type": "queue",
        "routing_key": "#",
        "arguments": {}
    }, {
        "source": "render",
        "vhost": "/",
        "destination": "me-render",
        "destination_type": "queue",
        "routing_key": "#.me-render",
        "arguments": {}
    }, {
        "source": "render",
        "vhost": "/",
        "destination": "render",
        "destination_type": "queue",
        "routing_key": "#.render",
        "arguments": {}
    }]
}
