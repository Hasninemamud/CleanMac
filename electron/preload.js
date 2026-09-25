'use strict';

const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('cleanmac', {
  overview: () => ipcRenderer.invoke('disk:overview'),
  scanJunk: () => ipcRenderer.invoke('junk:scan'),
  scanLarge: (opts) => ipcRenderer.invoke('large:scan', opts),
  findDuplicates: (files) => ipcRenderer.invoke('dupes:find', files),
  trash: (payload) => ipcRenderer.invoke('clean:trash', payload),
  reveal: (filePath) => ipcRenderer.invoke('shell:reveal', filePath),
  home: () => ipcRenderer.invoke('app:home'),
  setTheme: (theme) => ipcRenderer.invoke('app:theme', theme),
  onProgress: (cb) => {
    const handler = (_e, data) => cb(data);
    ipcRenderer.on('scan:progress', handler);
    return () => ipcRenderer.removeListener('scan:progress', handler);
  },
});
