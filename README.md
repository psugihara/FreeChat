# FreeChat

Chat with Meta’s Llama 2 on your MacBook without installing any other software or connecting to the internet. Every conversation is saved locally.

- Customize persona and expertise by changing the system prompt
- Try any llama.cpp compatible model
- No internet connection required, all local
- Conversations sync natively via iCloud

<img width="1308" alt="Screenshot 2023-08-18 at 4 06 42 PM" src="https://github.com/npc-pet/FreeChat/assets/282016/32ad0988-a391-40f4-b94a-479a06f9366d">


## Technical goals

FreeChat is a native LLM appliance for macOS that runs completely locally. Download it and ask your LLM a question without doing any configuration. Like OpenAI's chat without login or tracking. You should be able to install from the Mac App Store and use it immediatly.

- No config. Usable by people who haven't heard of models, prompts, or LLMs.
- Performance and simplicity over dev experience or features. Notes not Word, Swift not Elektron.
- Local first. Core functionality should not require an internet connection. There are lots of great clients for GPT-4, claude, etc. This is not one of them.
- No conversation tracking. Feel free to do whatever you want with your LLM, just like Notes.

## Install

Download the app here: <link to .zip>

Or build from source via "Archive" in Xcode after completing dev setup below.

## Dev Setup

Not sure what this is like to run on another machine. Try it out.

1. Download [codellama-7b-instruct.Q4_K_M.gguf](https://huggingface.co/TheBloke/CodeLlama-7B-Instruct-GGUF/blob/main/codellama-7b-instruct.Q4_K_M.gguf) to FreeChat/Models/NPC
2. Open FreeChat.xcodeproj
3. Run and fix errors?

### Roadmap / TODO (roughly in order):
- [ ] Chat with Llama 2 7B without installing anything else
  - [x] hook agent up, save convos to coredata
  - [x] server shuts down reliably even on force quit
  - [x] user can edit convo titles
  - [x] make intel chips work by [making a universal `server` binary](https://developer.apple.com/documentation/apple-silicon/building-a-universal-macos-binary#Update-the-Architecture-List-of-Custom-Makefiles)
  - [x] App icon
  - [x] New name
  - [x] Conversation null state
  - [x] user can copy conversation
  - [x] new conversation should focus textarea
  - [ ] toast notif for errors https://github.com/sanzaru/SimpleToast
  - [x] interrupt llama
  - [x] llama should pause for a moment before responding if text hasn't generated
  - [x] convo scroll behavior breaks on code blocks, syntax highligting would be nice

- [ ] Try any llama.cpp compatible model
  - [x] configure model in Settings
  - [ ] explain how to download models
- [x] Change system prompts to modify personas or expertise
- [ ] Search conversations
