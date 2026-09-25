'use strict';

/** @typedef {{ category: string, relativePath: string, safety: string, explanation: string, enumerateChildren?: boolean }} JunkRule */

/** @returns {JunkRule[]} */
function junkRules() {
  return [
    {
      category: 'userCaches',
      relativePath: 'Library/Caches',
      safety: 'safe',
      explanation: 'User application caches. Safe to clear; apps rebuild them.',
    },
    {
      category: 'logs',
      relativePath: 'Library/Logs',
      safety: 'safe',
      explanation: 'Application and system logs in your home Library.',
    },
    {
      category: 'trash',
      relativePath: '.Trash',
      safety: 'safe',
      explanation: 'Items already in Trash.',
    },
    {
      category: 'xcode',
      relativePath: 'Library/Developer/Xcode/DerivedData',
      safety: 'safe',
      explanation: 'Xcode build intermediates. Rebuild on next compile.',
    },
    {
      category: 'xcode',
      relativePath: 'Library/Developer/Xcode/iOS DeviceSupport',
      safety: 'review',
      explanation: 'Device symbols. Xcode re-downloads when needed.',
    },
    {
      category: 'xcode',
      relativePath: 'Library/Developer/Xcode/Archives',
      safety: 'review',
      explanation: 'Xcode archives. Keep if you need old builds.',
    },
    {
      category: 'packageManagers',
      relativePath: '.npm/_cacache',
      safety: 'safe',
      explanation: 'npm package cache.',
    },
    {
      category: 'packageManagers',
      relativePath: 'Library/Caches/CocoaPods',
      safety: 'safe',
      explanation: 'CocoaPods cache.',
    },
    {
      category: 'packageManagers',
      relativePath: 'Library/Caches/org.swift.swiftpm',
      safety: 'safe',
      explanation: 'Swift Package Manager cache.',
    },
    {
      category: 'packageManagers',
      relativePath: 'Library/Caches/pip',
      safety: 'safe',
      explanation: 'pip package cache.',
    },
    {
      category: 'packageManagers',
      relativePath: 'Library/Caches/Homebrew',
      safety: 'safe',
      explanation: 'Homebrew download cache.',
    },
    {
      category: 'packageManagers',
      relativePath: '.cache/yarn',
      safety: 'safe',
      explanation: 'Yarn cache.',
    },
    {
      category: 'packageManagers',
      relativePath: 'Library/pnpm/store',
      safety: 'review',
      explanation: 'pnpm content-addressable store.',
    },
    {
      category: 'browsers',
      relativePath: 'Library/Caches/com.apple.Safari',
      safety: 'safe',
      explanation: 'Safari cache.',
    },
    {
      category: 'browsers',
      relativePath: 'Library/Caches/Google/Chrome',
      safety: 'safe',
      explanation: 'Chrome cache.',
    },
    {
      category: 'browsers',
      relativePath: 'Library/Caches/Firefox',
      safety: 'safe',
      explanation: 'Firefox cache.',
    },
    {
      category: 'browsers',
      relativePath: 'Library/Caches/Microsoft Edge',
      safety: 'safe',
      explanation: 'Edge cache.',
    },
  ];
}

const CATEGORY_LABELS = {
  userCaches: 'User Caches',
  logs: 'Logs',
  trash: 'Trash',
  xcode: 'Xcode',
  packageManagers: 'Package Managers',
  browsers: 'Browsers',
  other: 'Other',
};

module.exports = { junkRules, CATEGORY_LABELS };
