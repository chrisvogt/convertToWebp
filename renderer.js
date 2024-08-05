const { ipcRenderer } = require('electron');

const dropArea = document.getElementById('drop-area');
const qualityInput = document.getElementById('quality');
const losslessInput = document.getElementById('lossless');
const convertButton = document.getElementById('convert-button');
const viewButton = document.getElementById('view-button');
const backButton = document.getElementById('back-button');
const status = document.getElementById('status');

let folderPath = '';

dropArea.addEventListener('dragover', (event) => {
    event.preventDefault();
});

dropArea.addEventListener('drop', (event) => {
    event.preventDefault();
    folderPath = event.dataTransfer.files[0].path;
    dropArea.textContent = `Folder Selected: ${folderPath}`;
});

convertButton.addEventListener('click', () => {
    const quality = parseInt(qualityInput.value) || 80;
    const lossless = losslessInput.checked;
    if (folderPath) {
        ipcRenderer.send('convert-folder', folderPath, quality, lossless);
        status.textContent = 'Conversion in progress...';
    } else {
        status.textContent = 'Please select a folder first.';
    }
});

ipcRenderer.on('conversion-done', (event, err, result) => {
    if (err) {
        status.textContent = `Error: ${err.message}`;
    } else {
        status.textContent = 'Conversion complete!';
        viewButton.disabled = false;
    }
});

viewButton.addEventListener('click', () => {
    if (folderPath) {
        ipcRenderer.send('start-server', folderPath);
    }
});

ipcRenderer.on('server-started', (event, err, url) => {
    if (err) {
        status.textContent = `Error: ${err.message}`;
    } else {
        // Open the URL inside the Electron window
        ipcRenderer.send('load-url', url);
    }
});

if (backButton) {
    backButton.addEventListener('click', () => {
        ipcRenderer.send('go-back');
    });
}
