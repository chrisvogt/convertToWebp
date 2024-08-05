const { app, BrowserWindow, ipcMain } = require('electron');
const path = require('path');
const { convertToWebp, startServer } = require('./convertToWebp.js');

let mainWindow;
let server;

function createWindow() {
    mainWindow = new BrowserWindow({
        width: 800,
        height: 600,
        webPreferences: {
            preload: path.join(__dirname, 'preload.js'),
            contextIsolation: false,
            nodeIntegration: true
        }
    });

    mainWindow.loadFile('index.html');
}

app.whenReady().then(() => {
    createWindow();

    app.on('activate', () => {
        if (BrowserWindow.getAllWindows().length === 0) createWindow();
    });
});

app.on('window-all-closed', () => {
    if (process.platform !== 'darwin') app.quit();
});

ipcMain.on('convert-folder', (event, folderPath, quality, lossless) => {
    convertToWebp(folderPath, quality, lossless, (err, result) => {
        event.sender.send('conversion-done', err, result);
    });
});

ipcMain.on('start-server', async (event, folderPath) => {
    if (server) server.close();
    server = await startServer(folderPath, (err, url) => {
        if (err) {
            event.sender.send('server-started', err, url);
        } else {
            mainWindow.loadURL(url);
            event.sender.send('server-started', err, url);
        }
    });
});

ipcMain.on('go-back', () => {
    mainWindow.loadFile('index.html');
});
