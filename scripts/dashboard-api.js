#!/usr/bin/env node

const http = require('http');
const { spawn } = require('child_process');
const path = require('path');
const url = require('url');

const PORT = 3998;
const PROJECT_ROOT = path.resolve(__dirname, '..');
const AUTOSTART_SCRIPT = path.join(__dirname, 'autostart-service.sh');

// CORS headers for browser requests
const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
    'Content-Type': 'application/json'
};

function sendResponse(res, statusCode, data) {
    res.writeHead(statusCode, corsHeaders);
    res.end(JSON.stringify(data));
}

function executeAutoStart(service, targetUrl, callback) {
    console.log(`Starting auto-start for service: ${service}, URL: ${targetUrl}`);
    
    const child = spawn('bash', [AUTOSTART_SCRIPT, 'start', service, targetUrl], {
        cwd: PROJECT_ROOT,
        stdio: ['ignore', 'pipe', 'pipe']
    });
    
    let stdout = '';
    let stderr = '';
    
    child.stdout.on('data', (data) => {
        stdout += data.toString();
        console.log(`[${service}] ${data.toString().trim()}`);
    });
    
    child.stderr.on('data', (data) => {
        stderr += data.toString();
        console.error(`[${service} ERROR] ${data.toString().trim()}`);
    });
    
    child.on('close', (code) => {
        callback(code === 0, {
            code,
            stdout: stdout.trim(),
            stderr: stderr.trim()
        });
    });
    
    child.on('error', (error) => {
        console.error(`Failed to start service ${service}:`, error);
        callback(false, {
            error: error.message,
            stderr: error.toString()
        });
    });
}

const server = http.createServer((req, res) => {
    // Handle CORS preflight
    if (req.method === 'OPTIONS') {
        res.writeHead(200, corsHeaders);
        res.end();
        return;
    }
    
    const parsedUrl = url.parse(req.url, true);
    const pathname = parsedUrl.pathname;
    const query = parsedUrl.query;
    
    console.log(`${req.method} ${pathname}`, query);
    
    if (pathname === '/health') {
        sendResponse(res, 200, { status: 'healthy', timestamp: new Date().toISOString() });
        return;
    }
    
    if (pathname === '/autostart' && req.method === 'GET') {
        const { service, url: targetUrl } = query;
        
        if (!service || !targetUrl) {
            sendResponse(res, 400, {
                error: 'Missing required parameters: service and url'
            });
            return;
        }
        
        // Send immediate response to avoid browser timeout
        sendResponse(res, 200, {
            status: 'starting',
            service,
            url: targetUrl,
            message: `Starting service ${service}...`
        });
        
        // Execute auto-start in background
        executeAutoStart(service, targetUrl, (success, result) => {
            if (success) {
                console.log(`✅ Service ${service} started successfully`);
            } else {
                console.error(`❌ Failed to start service ${service}:`, result);
            }
        });
        
        return;
    }
    
    if (pathname === '/autostart' && req.method === 'POST') {
        let body = '';
        
        req.on('data', (chunk) => {
            body += chunk.toString();
        });
        
        req.on('end', () => {
            try {
                const { service, url: targetUrl } = JSON.parse(body);
                
                if (!service || !targetUrl) {
                    sendResponse(res, 400, {
                        error: 'Missing required parameters: service and url'
                    });
                    return;
                }
                
                // Send immediate response
                sendResponse(res, 200, {
                    status: 'starting',
                    service,
                    url: targetUrl,
                    message: `Starting service ${service}...`
                });
                
                // Execute auto-start in background
                executeAutoStart(service, targetUrl, (success, result) => {
                    if (success) {
                        console.log(`✅ Service ${service} started successfully`);
                    } else {
                        console.error(`❌ Failed to start service ${service}:`, result);
                    }
                });
                
            } catch (error) {
                sendResponse(res, 400, {
                    error: 'Invalid JSON in request body'
                });
            }
        });
        
        return;
    }
    
    // 404 for unknown endpoints
    sendResponse(res, 404, {
        error: 'Not found',
        availableEndpoints: [
            'GET /health',
            'GET /autostart?service=<name>&url=<url>',
            'POST /autostart (JSON body with service and url)'
        ]
    });
});

server.listen(PORT, '127.0.0.1', () => {
    console.log(`🚀 Dashboard API server running at http://127.0.0.1:${PORT}`);
    console.log(`📂 Project root: ${PROJECT_ROOT}`);
    console.log(`🔧 Autostart script: ${AUTOSTART_SCRIPT}`);
    console.log('\nAvailable endpoints:');
    console.log(`  GET  http://127.0.0.1:${PORT}/health`);
    console.log(`  GET  http://127.0.0.1:${PORT}/autostart?service=<name>&url=<url>`);
    console.log(`  POST http://127.0.0.1:${PORT}/autostart`);
});

// Graceful shutdown
process.on('SIGINT', () => {
    console.log('\n🛑 Shutting down dashboard API server...');
    server.close(() => {
        console.log('✅ Server closed');
        process.exit(0);
    });
});

process.on('SIGTERM', () => {
    console.log('\n🛑 Received SIGTERM, shutting down...');
    server.close(() => {
        console.log('✅ Server closed');
        process.exit(0);
    });
});
