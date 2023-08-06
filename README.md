# Chats

Chat with Meta’s Llama 2 on your MacBook without installing any other software or connecting to the internet. Every conversation is saved locally.

- Try any llama.cpp compatible model
- Customize personas and expertise with system prompts
- Search conversations

<img width="1162" alt="Screenshot 2023-08-05 at 8 30 04 PM" src="https://github.com/npc-pet/Chats/assets/282016/d34d87e2-3c0d-4359-a68a-0872f7066601">


## Dev

Not sure what this is like to run on another machine. Try it out.

1. Download [llama-2-7b-chat.ggmlv3.q4_1.bin](https://huggingface.co/TheBloke/Llama-2-7B-Chat-GGML/tree/main) to Mantras/NPC
2. Open Mantras.xcodeproj
3. Run and fix errors?

### Roadmap / TODO (roughly in order):
- [ ] Chat with Llama 2 7B without installing anything else
  - [x] hook agent up, save convos to coredata
  - [ ] server should shut down more reliably, try storing pids and reaping orphans
    - tried this but sandbox prevents killing processes that were not started by the current process. Could try starting a reaper daemon 
  - [ ] user can edit convo titles
  - [ ] make intel chips work by [making a universal `server` binary](https://developer.apple.com/documentation/apple-silicon/building-a-universal-macos-binary#Update-the-Architecture-List-of-Custom-Makefiles)
  - [ ] App icon
  - [ ] Conversation null state
  - [ ] user can copy conversation
  - [ ] breaks on super long chats

- [ ] Try any llama.cpp compatible model
- [ ] Change system prompts to modify personas or expertise
- [ ] Search conversations
