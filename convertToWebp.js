const fs = require('fs');
const path = require('path');
const { exec } = require('child_process');
const express = require('express');
const getPort = require('get-port');

function formatSize(size) {
    return (size / 1024).toFixed(2) + ' KB';
}

function createHTMLFile(outputDir, templateFile, data) {
    let template = fs.readFileSync(templateFile, 'utf-8');
    for (const key in data) {
        template = template.replace(new RegExp(`<!-- ${key.toUpperCase()} -->`, 'g'), data[key]);
    }
    fs.writeFileSync(path.join(outputDir, 'index.html'), template);
}

function generateIndexHTML(baseDir, templatesDir) {
    const mainIndexFile = path.join(baseDir, 'index.html');
    const cardTemplate = fs.readFileSync(path.join(templatesDir, 'card_template.html'), 'utf-8');
    const commonHead = fs.readFileSync(path.join(templatesDir, 'common_head.html'), 'utf-8');
    const commonTail = fs.readFileSync(path.join(templatesDir, 'common_tail.html'), 'utf-8');
    const header = fs.readFileSync(path.join(templatesDir, 'header.html'), 'utf-8');
    const footer = fs.readFileSync(path.join(templatesDir, 'footer.html'), 'utf-8');

    let cards = '';
    const dirs = fs.readdirSync(baseDir).filter(f => fs.statSync(path.join(baseDir, f)).isDirectory() && f.startsWith('conversion_q'));
    dirs.forEach(dir => {
        const logFile = path.join(baseDir, dir, 'conversion.log');
        if (fs.existsSync(logFile)) {
            const logData = fs.readFileSync(logFile, 'utf-8');
            const [qualityLine, losslessLine, , filesizeSavedLine, timeLine] = logData.split('\n');
            const cardContent = cardTemplate
                .replace('<!-- LINK_PLACEHOLDER -->', `${dir}/index.html`)
                .replace('<!-- LINK_NAME -->', dir)
                .replace('<!-- QUALITY_PLACEHOLDER -->', qualityLine.replace('Quality: ', ''))
                .replace('<!-- LOSSLESS_PLACEHOLDER -->', losslessLine.replace('Lossless: ', ''))
                .replace('<!-- FILESIZE_SAVED_PLACEHOLDER -->', filesizeSavedLine.replace('Total filesize saved: ', ''))
                .replace('<!-- TIME_PLACEHOLDER -->', timeLine.replace('Total time: ', ''));
            cards += cardContent;
        }
    });

    const indexContent = `${commonHead}${header}<main class="container mx-auto p-4"><h2 class="text-2xl font-bold mb-4">Conversion Results</h2><div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">${cards}</div></main>${footer}${commonTail}`;
    fs.writeFileSync(mainIndexFile, indexContent);
}

function convertToWebp(folderPath, quality, lossless, callback) {
    const templatesDir = path.join(__dirname, 'templates');
    const outputDir = path.join(folderPath, `conversion_q${quality}${lossless ? '_lossless' : ''}`);
    if (!fs.existsSync(outputDir)) {
        fs.mkdirSync(outputDir);
    }

    const logfile = path.join(outputDir, 'conversion.log');
    const startTime = Date.now();

    fs.readdir(folderPath, (err, files) => {
        if (err) return callback(err);

        const images = files.filter(file => file.match(/\.(jpg|jpeg|png|bmp|gif|tiff)$/i));

        let completed = 0;
        let totalOriginalSize = 0;
        let totalConvertedSize = 0;

        images.forEach(image => {
            const inputPath = path.join(folderPath, image);
            const outputPath = path.join(outputDir, `${path.parse(image).name}.webp`);
            const cwebpCmd = `cwebp -q ${quality} ${lossless ? '-lossless' : ''} "${inputPath}" -o "${outputPath}"`;

            exec(cwebpCmd, (err, stdout, stderr) => {
                if (err) {
                    callback(err);
                    return;
                }

                const originalSize = fs.statSync(inputPath).size;
                const convertedSize = fs.statSync(outputPath).size;
                totalOriginalSize += originalSize;
                totalConvertedSize += convertedSize;

                const logEntry = `${image} -> ${path.basename(outputPath)}: ${formatSize(originalSize)} -> ${formatSize(convertedSize)} | Quality: ${quality} | Lossless: ${lossless}\n`;
                fs.appendFileSync(logfile, logEntry);

                completed++;
                if (completed === images.length) {
                    const totalTime = ((Date.now() - startTime) / 1000).toFixed(2);
                    const percentSaved = ((1 - totalConvertedSize / totalOriginalSize) * 100).toFixed(2);
                    const summary = `Total filesize saved: ${percentSaved}%\nTotal time: ${totalTime} seconds\n`;
                    fs.appendFileSync(logfile, summary);

                    createHTMLFile(outputDir, path.join(templatesDir, 'template.html'), {
                        content: images.map(image => {
                            const originalPath = path.join(folderPath, image);
                            const convertedPath = path.join(outputDir, `${path.parse(image).name}.webp`);
                            const originalSize = formatSize(fs.statSync(originalPath).size);
                            const convertedSize = formatSize(fs.statSync(convertedPath).size);
                            return `<tr><td><a href="../${image}" target="_blank"><img src="../${image}" alt="${image}"><small>Original: ${originalSize}</small></a></td><td><a href="${path.basename(convertedPath)}" target="_blank"><img src="${path.basename(convertedPath)}" alt="${path.basename(convertedPath)}"><small>Converted: ${convertedSize}</small></a></td></tr>`;
                        }).join('\n')
                    });

                    generateIndexHTML(folderPath, templatesDir);

                    callback(null, `Converted ${completed} images`);
                }
            });
        });
    });
}

async function startServer(folderPath, callback) {
    const app = express();
    const port = await getPort();

    app.use(express.static(folderPath));

    const server = app.listen(port, () => {
        console.log(`Server started at http://localhost:${port}`);
        callback(null, `http://localhost:${port}`);
    });

    return server;
}

module.exports = { convertToWebp, startServer };
