'use strict';

const { app, BrowserWindow, ipcMain, shell, nativeTheme, Menu } = require('electron');
const path = require('path');
const {
  scanJunk,
  scanOverview,
  collectLargeFiles,
  findDuplicates,
  homeDir,
} = require('../src/core');
const { trashSelected } = require('../src/core/cleaner');

let mainWindow = null;

function createWindow() {
  nativeTheme.themeSource = 'system';

  mainWindow = new BrowserWindow({
    width: 1100,
    height: 740,
    minWidth: 900,
    minHeight: 600,
    title: 'CleanMac',
    transparent: true,
    backgroundColor: '#00000000',
    vibrancy: 'under-window',
    visualEffectState: 'followWindow',
    titleBarStyle: 'hiddenInset',
    trafficLightPosition: { x: 16, y: 18 },
    hasShadow: true,
    roundedCorners: true,
    show: false,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true,
    },
  });

  mainWindow.once('ready-to-show', () => mainWindow.show());
  mainWindow.loadFile(path.join(__dirname, '../src/ui/index.html'));
}

function sendProgress(channel, data) {
  if (mainWindow && !mainWindow.isDestroyed()) {
    mainWindow.webContents.send(channel, data);
  }
}

app.whenReady().then(() => {
  if (process.platform === 'darwin') {
    app.setName('CleanMac');
    Menu.setApplicationMenu(
      Menu.buildFromTemplate([
        {
          label: app.name,
          submenu: [
            { role: 'about' },
            { type: 'separator' },
            { role: 'hide' },
            { role: 'hideOthers' },
            { role: 'unhide' },
            { type: 'separator' },
            { role: 'quit' },
          ],
        },
        { role: 'editMenu' },
        { role: 'windowMenu' },
      ])
    );
  }

  createWindow();

  ipcMain.handle('disk:overview', async () => {
    return scanOverview((p) => sendProgress('scan:progress', p));
  });

  ipcMain.handle('junk:scan', async () => {
    return scanJunk((p) => sendProgress('scan:progress', p));
  });

  ipcMain.handle('large:scan', async (_e, opts = {}) => {
    const root = opts.root || homeDir();
    const minBytes = opts.minBytes ?? 50 * 1024 * 1024;
    return collectLargeFiles(root, { minBytes }, (p) => sendProgress('scan:progress', p));
  });

  ipcMain.handle('dupes:find', async (_e, files) => {
    return findDuplicates(files || [], {}, (p) => sendProgress('scan:progress', p));
  });

  ipcMain.handle('clean:trash', async (_e, { items, selectedPaths }) => {
    return trashSelected(items || [], selectedPaths || [], (p) => shell.trashItem(p));
  });

  ipcMain.handle('shell:reveal', async (_e, filePath) => {
    shell.showItemInFolder(filePath);
  });

  ipcMain.handle('app:home', () => homeDir());

  ipcMain.handle('app:theme', (_e, theme) => {
    nativeTheme.themeSource = theme === 'dark' ? 'dark' : 'light';
    if (mainWindow && !mainWindow.isDestroyed()) {
      mainWindow.setBackgroundColor('#00000000');
    }
    return theme;
  });

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit();
});
