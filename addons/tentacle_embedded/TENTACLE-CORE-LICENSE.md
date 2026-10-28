# Tentacle Core License 1.0

Copyright (c) 2026 Eldritch One. All rights reserved, except as this license grants below.

This is version 1.0 of this license, numbered separately from Tentacle Core itself.

## In short

This summary is for convenience. The terms below are what apply.

- Tentacle Core is free to use for any purpose, in every version. The only limit on using it: don't modify or reverse engineer it.
- You may ship it inside your own game, app, mod, or streaming tool for free, on the conditions in section 3.
- Every copy keeps the terms it came with. Later versions may change the terms for redistributing them, but never for using them.
- The Tentacle plugins and the tentacle-web package are licensed separately, under the MIT License.

## Terms

### 1. Definitions and acceptance

**Tentacle Core** is the compiled Tentacle core library we release with these terms, whether or not these terms come with a particular copy: the `tentacle_ffi` library, the `tentacle_godot` library, the `tentacle-core` Node addon, and any other build of it we release, for any platform, dynamic or static. Files that come alongside it, such as `.gdextension` and `.meta` files, the `tentacle_ffi.h` header, and the tentacle-core npm package's `index.js` and `index.d.ts`, keep the license of the plugin or package they are in. The copy inside the Tentacle desktop app falls under the app's Terms of Service instead, and a copy we released under other terms, such as in an earlier MIT plugin release, keeps those terms.

**The notices** are the third-party notices we release with Tentacle Core. **We** are Eldritch One.

**You** are whoever accepts these terms. If you accept them for an organization, they bind it, and its employees, contractors, and affiliates may use Tentacle Core on its behalf.

**Your product** is a game, app, or other software that you develop, or have developed for you, and that includes Tentacle Core or gets a copy of it when installed or run, as long as it isn't mainly a way for other developers' software to use Tentacle Core or its features.

- These can be your product: a game, a mod, a streaming overlay, a chat bot, a plugin for streaming software such as OBS, Stream Deck, or VNyan, another tool streamers use with their own stream, and a free sample or tutorial project.
- These are not, when that is mainly what they are: a software development kit, a library, a plugin for a game engine or development tool, a template or starter kit for other people's products, and an app that other developers' software connects to for Twitch or Kick features.

You accept these terms by copying, using, or distributing Tentacle Core, both as conditions of your licenses and as obligations.

### 2. Using Tentacle Core

We grant you a perpetual, worldwide, non-exclusive, royalty-free license, at no charge, to copy, install, run, and otherwise use Tentacle Core for any purpose, including commercial ones and running it as a service for others.

Giving copies to people who develop your product with you, or who use Tentacle Core on your behalf, is use. Giving copies to anyone else is redistribution (section 3), and so is having your product or its installer fetch a copy for others to use.

### 3. Shipping Tentacle Core in your product

We grant you a perpetual, worldwide, non-exclusive, royalty-free license, at no charge, to distribute Tentacle Core as part of your product, its updates, patches, and downloadable content, including copies your product or its installer fetches for its users, as long as:

1. you don't distribute it on its own or in anything that isn't your product (a server only for your product's fetches is fine);
2. you don't change its code;
3. your product includes these terms and the notices, for example with its other licenses, in its credits or documentation, or as text files; and
4. you give no one more rights in Tentacle Core than to use it as part of your product and pass your product on as this section allows, and you exclude its files from your product's own license.

Also:

- Your publishers, distributors, stores, platform holders, cloud gaming services, and contractors may copy, host, run, and distribute it as part of your product for you, and antivirus, anti-cheat, crash-reporting, and certification services may receive a copy to check your product. A store, platform, or mod host whose standard upload terms take, or have you grant its users, broader rights doesn't put you in breach, but gets no more rights in Tentacle Core than this section gives.
- Steps that leave what Tentacle Core does unchanged aren't changing or modifying it, whoever takes them: signing, compressing, encrypting, packing, obfuscating, anti-tamper, renaming, stripping symbols, merging builds for different processors, embedding in an installer or executable, and linking, with optimization.
- A mod kit or level editor made only for making content for your product counts as part of it, even when distributed separately.
- Your product's project files and source code may include the Tentacle plugins, changed or not, with Tentacle Core in them, and if you publish that source code, others may copy it to work on or build your product.
- Anyone who receives Tentacle Core as part of your product may use it as part of that product without accepting these terms, and may pass your product on as a whole wherever you allow. Sections 8, 11, and 12 apply to them as to you.

### 4. Limits

Apart from what applicable law lets you do regardless, you may not modify, reverse engineer, decompile, or disassemble Tentacle Core, or sublicense it except as section 3 allows. You may still inspect it with debuggers, profilers, disassemblers, or similar tools to diagnose or measure problems in your own product, or to review its security or network traffic, and you may tell anyone what you find, though we ask that you report security problems to us first and give us reasonable time to fix them.

These terms grant no rights in the names, logos, or trademarks of Tentacle or Eldritch One, except to say truthfully that your product uses Tentacle.

### 5. Versions and future terms

These terms apply to the version of Tentacle Core we release them with. If that is a stable release (no "-" in its version, such as 1.2.0), they also apply to every later release of the same major and minor version (every 1.2.x), and if we also release one of those with other terms, you may choose either. A pre-release (such as 1.3.0-alpha.1) extends its terms to nothing else, and a development build (with "-dev" in its version or file names) belongs to no version line and comes only under the terms we publish it with. Any other version comes under the terms we release it with, whatever files you keep beside it.

Your licenses can't be revoked except under section 10.

We reserve the right to release later versions under different terms for redistributing them, which may include requiring a paid license. That covers redistribution only: every later version we release is licensed, to you and anyone who receives it, for use as sections 2 and 8 describe, at no charge and with no conditions or limits on that use beyond sections 4 and 6, whatever other terms it comes with.

A later version's different terms never apply to a copy your product carries but isn't set up to run, such as a build that only connects to the Tentacle app in Paired mode, even if the library loads at startup, as long as neither you nor anyone acting for you offers or encourages a way to make it run. You may distribute such a copy at no charge, on conditions no stricter than section 3's. If you later set it up to run, the later terms apply from then on, including to copies already out, but nothing is owed for the time before.

### 6. Our services

By default, Tentacle Core connects to services we run: it checks ours for configuration at startup and every six hours, whether or not you use Kick, and signs players in to Kick, and refreshes their sign-ins, through our Kick sign-in service. Each request reaches us with the internet address it comes from and the version of Tentacle Core sending it, and Kick sign-in requests carry the player's Kick sign-in, which we pass to Kick and don't keep, so your privacy policy may need to mention them.

By default, it also signs players in to Twitch and Kick through our Twitch and Kick applications, so the platforms' sign-in pages name Tentacle. Your product may use them, or its own applications where Tentacle Core lets you set them, so that those pages name your product instead.

These terms give you no right to keep using our services or applications. We may change, limit, or stop them, or block uses that abuse them or break Twitch's or Kick's terms, but we won't limit, stop, or charge for them for a version because of the terms it came with, or to push anyone onto a later version or a paid license. You are responsible for following the developer terms of the platforms your product connects to.

### 7. Third-party components

Tentacle Core includes open-source code and data made by others, listed in the notices. Their licenses apply to those components, and don't extend to the rest of Tentacle Core.

### 8. Patents

We grant you a perpetual, worldwide, royalty-free license under every patent claim we own or control, now or later, that Tentacle Core as we released it would infringe, alone or as meant to be used in a product, to make, have made, use, sell, offer for sale, import, and otherwise distribute it as these terms allow. Anyone who receives Tentacle Core as part of your product gets the same license for using it there.

### 9. Transfers

You may transfer your licenses to anyone who takes over your product or business, if they agree to these terms. We will transfer our rights in Tentacle Core only to someone who agrees to be bound by these terms, including our promises in sections 5 and 6, and anyone we transfer them to is bound by them.

### 10. If these terms are broken

If you break these terms, we may tell you in writing what the breach is. Your licenses continue if, within 30 days of that notice, you correct it and take practical steps to correct past breaches of the same kind, such as removing Tentacle Core from copies still on sale. If the fix needs a store's or platform holder's approval or a certified build, starting it within the 30 days, submitting it promptly, and releasing it once approved is enough, as long as you pursue approval in good faith. Once fixed, we won't make any claim over it or those past breaches, except to recover money you received for distributing Tentacle Core on its own or in something that isn't your product.

Otherwise, your licenses for the products involved end when the 30 days run out, or all your licenses if the breach doesn't concern one of your products. Anyone who received Tentacle Core as part of your product before then keeps the right to use it there, with section 8's license, including copies they download again from the same store or service.

### 11. No warranty

**Tentacle Core is provided as is, without warranty or condition of any kind, express or implied, including any warranty of merchantability, fitness for a particular purpose, or non-infringement.**

### 12. No liability

**To the extent the law allows, Eldritch One is not liable for any damages arising out of these terms or the use or nature of Tentacle Core, under any kind of legal claim.** This doesn't limit your remedies, other than damages, if we break our promises in sections 5, 6, 9, or 10.

### 13. General

California law governs these terms. If any part of them can't be enforced, the rest still applies, and not enforcing a part right away doesn't waive it. Sections 11 and 12, and section 8 for what happened before, survive the end of your licenses. A separate agreement changes these terms only if both of us sign it and it says so. You are responsible for the export and sanctions laws that apply to how you distribute Tentacle Core.

We send notices to the contact details you most recently gave us or, if none, to those published for your product (such as on its store page), effective on delivery. Send questions and notices about these terms to support@tentacle.live.

Eldritch One signs this license by publishing it under its name above.
