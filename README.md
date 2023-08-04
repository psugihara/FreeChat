# Chats

Chat with Meta’s Llama 2 on your MacBook without installing any other software or connecting to the internet. Every conversation is saved locally.


<img width="1009" alt="Screenshot 2023-08-04 at 1 39 52 PM" src="https://github.com/npc-pet/Chats/assets/282016/c3216351-2b7a-40c7-9fe6-d78ec5f3d0b3">

## Dev

Not sure what this is like to run on another machine. Try it out.

1. Download [llama-2-7b-chat.ggmlv3.q4_1.bin](https://huggingface.co/TheBloke/Llama-2-7B-Chat-GGML/tree/main) to Mantras/NPC
2. Open Mantras.xcodeproj
3. Run and fix errors?

### Roadmap / TODO (roughly in order):
- [ ] Chat with Llama 2 7B without installing anything else
  - [x] hook agent up, save convos to coredata
  - [ ] server should shut down more reliably, try storing pids and reaping orphans
  - [ ] user can edit convo titles
  - [ ] make intel chips work by [making a universal `server` binary](https://developer.apple.com/documentation/apple-silicon/building-a-universal-macos-binary#Update-the-Architecture-List-of-Custom-Makefiles)
  - [ ] App icon
  - [ ] Conversation null state
  - [ ] user can copy conversation

- [ ] Try any llama.cpp compatible model
- [ ] Change system prompts to modify personas or expertise
- [ ] Search conversations
