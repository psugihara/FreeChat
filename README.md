# FreeChat

Chat with Meta’s Llama 2 on your MacBook without installing any other software or connecting to the internet. Every conversation is saved locally.

- Try any llama.cpp compatible model
- Customize persona and expertise by changing the system prompt
- Conversations sync via iCloud

<img width="1308" alt="Screenshot 2023-08-18 at 4 06 42 PM" src="https://github.com/npc-pet/FreeChat/assets/282016/32ad0988-a391-40f4-b94a-479a06f9366d">


## Philosophy

We have 2 goals with:
- A native macOS LLM appliance that runs completely locally. You should just be able to open it and ask your LLM a question without doing any configuration. Like OpenAI's chat without login or tracking. You should be able to install from the Mac App Store and use it immediatly.
- Proof of concept for running llama.cpp server in a 0-config mac app.

## Install

Download the app here: <link to .zip>

Or build from source.

## Dev Setup

Not sure what this is like to run on another machine. Try it out.

1. Download [llama-2-7b-chat.ggmlv3.q4_1.bin](https://huggingface.co/TheBloke/Llama-2-7B-Chat-GGML/tree/main) to Mantras/NPC
2. Open Chats.xcodeproj
3. Run and fix errors?

### Roadmap / TODO (roughly in order):
- [ ] Chat with Llama 2 7B without installing anything else
  - [x] hook agent up, save convos to coredata
  - [x] server shuts down reliably even on force quit
  - [x] user can edit convo titles
  - [x] make intel chips work by [making a universal `server` binary](https://developer.apple.com/documentation/apple-silicon/building-a-universal-macos-binary#Update-the-Architecture-List-of-Custom-Makefiles)
  - [ ] App icon
  - [x] New name
  - [ ] Conversation null state
  - [x] user can copy conversation
  - [x] new conversation should focus textarea
  - [ ] toast notif for errors https://github.com/sanzaru/SimpleToast
  - [x] interrupt llama
  - [ ] llama should pause for a moment before responding if text hasn't generated
  - [x] convo scroll behavior breaks on code blocks, syntax highligting would be nice

- [ ] Try any llama.cpp compatible model
  - [x] configure model in Settings
  - [ ] explain how to download models
- [x] Change system prompts to modify personas or expertise
- [ ] Search conversations
