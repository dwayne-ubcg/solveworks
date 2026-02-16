const puppeteer = require('puppeteer');
const path = require('path');

async function generatePDF() {
    const browser = await puppeteer.launch();
    const page = await browser.newPage();
    
    const htmlFile = process.argv[2] || 'revaly-proposal.html';
    const pdfFile = process.argv[3] || 'revaly-proposal.pdf';
    const htmlPath = path.join(__dirname, htmlFile);
    const pdfPath = path.join(__dirname, pdfFile);
    
    await page.goto(`file://${htmlPath}`, { waitUntil: 'networkidle0' });
    
    await page.pdf({
        path: pdfPath,
        format: 'Letter',
        printBackground: true,
        margin: {
            top: '0',
            right: '0',
            bottom: '0',
            left: '0'
        }
    });
    
    await browser.close();
    console.log(`PDF generated successfully: ${pdfPath}`);
}

generatePDF().catch(console.error);