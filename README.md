# CleanStore

## CFA migration demonstration

This fork is migrating the original Clean Swift sample to SwiftUI (iOS 17+),
Cooperative Feature Architecture and Swift Concurrency using the CFA AI Toolkit
for iOS v0.3. It keeps the original order workflows and process-only demo storage.
Core Data remains a separately tested alternative, not the live store.

Checkpoint 4 retires the unused VIP/callback implementations after replacement
tests pass. Read [the checkpoint ledger](MIGRATION.md) and
[the behaviour/coverage contract](MIGRATION_BEHAVIOUR_CONTRACT.md) for evidence,
approved differences and remaining validation. Verified with Xcode 26.2; Swift
language mode remains 5. This is not a production payment application—use only
synthetic card data.

## Original project

The original authorship, licence and description are retained below. These badges
describe the upstream project, not this migration branch's current toolchain.

[![IDE](https://img.shields.io/badge/Xcode-10-blue.svg)](https://developer.apple.com/xcode/)
[![Language](https://img.shields.io/badge/swift-4-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/iOS-12-green.svg)](https://developer.apple.com/ios/)
[![Build Status](https://travis-ci.org/Clean-Swift/CleanStore.svg?branch=master)](https://travis-ci.org/Clean-Swift/CleanStore)
[![License](https://img.shields.io/github/license/Clean-Swift/CleanStore.svg)](LICENSE)

A sample iOS app built using the Clean Swift architecture. Clean Swift is Uncle Bob's Clean Architecture applied to iOS and Mac projects. CleanStore demonstrates Clean Swift by implementing the create order use case described by in Uncle Bob's talks.
