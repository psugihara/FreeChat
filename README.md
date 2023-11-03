<p align="center" width="100%">
<img width="120" alt="FreeChat app icon" src="https://github.com/psugihara/FreeChat/assets/282016/26be9d7a-fc18-476d-b0eb-13c4a37cfc54">
</p>

<h1 align="center">FreeChat</h1>

Chat with LLMs on your Mac without installing any other software. Every conversation is saved locally, all conversations happen offline.

- Customize persona and expertise by changing the system prompt
- Try any llama.cpp compatible model
- No internet connection required, all local

https://github.com/psugihara/FreeChat/assets/282016/fd546e39-7657-4ccd-a44f-0b872547a629

## Install

Join the TestFlight beta: https://6032904148827.gumroad.com/l/freechat-beta

Or download on the Mac App Store: https://apps.apple.com/us/app/freechat/id6458534902

Or build from source via "Archive" in Xcode after completing dev setup below.

## Goals

The main goal of FreeChat is to make open, local, private models accessible to more people.

FreeChat is a native LLM appliance for macOS that runs completely locally. Download it and ask your LLM a question without doing any configuration. A local/llama version of OpenAI's chat without login or tracking. You should be able to install from the Mac App Store and use it immediatly.

- No config. Usable by people who haven't heard of models, prompts, or LLMs.
- Performance and simplicity over dev experience or features. Notes not Word, Swift not Elektron.
- Local first. Core functionality should not require an internet connection. There are lots of great clients for GPT-4, claude, etc. This is not one of them.
- No conversation tracking. Talk about whatever you want with FreeChat, just like Notes.
- Open source. What's the point of running local AI if you can't audit that it's actually running locally?

### Upgrade your models

Once you're up and running, it's fun to try different models in FreeChat. The AI training community is releasing new models basically every day. FreeChat is compatible with any gguf formatted model that [llama.cpp](https://github.com/ggerganov/llama.cpp) works with. Models can be found on [HuggingFace](https://huggingface.co/models?sort=trending&search=gguf). Most models have a "model card" by the author that discusses its training and abilities.

Models are usually named with their parameter count (e.g. 7B) and are formatted with different levels of lossy compression applied (quantization). The general rule of thumb is that models with more parameters tend to be slower and wiser and more quantization makes it dumber.

Here are a few we've tried and recommend:

#### Spicyboros

This is a fun Llama 2 based model for uncensored chat.

- [Spicyboros-7B-2.2-GGUF](https://huggingface.co/TheBloke/Spicyboros-7B-2.2-GGUF?not-for-all-audiences=true)
- [Spicyboros-13B-2.2-GGUF](https://huggingface.co/TheBloke/Spicyboros-13B-2.2-GGUF?not-for-all-audiences=true)
- [Spicyboros-70B-2.2-GGUF](https://huggingface.co/TheBloke/Spicyboros-70B-2.2-GGUF?not-for-all-audiences=true)

#### Code Llama

This is the latest set of Llama models from Meta. It is a version of their last foundation model, Llama 2, with additional training on coding tasks. It's good at programming but also has wider knowledge. Read the release note [here](https://about.fb.com/news/2023/08/code-llama-ai-for-coding/).

- [CodeLlama-7B-GGUF](https://huggingface.co/TheBloke/CodeLlama-7B-GGUF)
- [CodeLlama-13B-GGUF](https://huggingface.co/TheBloke/CodeLlama-13B-GGUF)
- [CodeLlama-34B-GGUF](https://huggingface.co/TheBloke/CodeLlama-34B-GGUF)
- [Llama-2-70B-chat-GGUF](https://huggingface.co/TheBloke/Llama-2-70B-chat-GGUF)

#### Samantha

This is an interesting model that's inspired by the AI in the 2013 movie "Her", also named Samantha. It's based on Meta's foundation Llama models but has been trained on philosophy, psychology, and personal relationships. She's an assistant but also want to be a friend.

- [Samantha-1.11-13B-GGUF](https://huggingface.co/TheBloke/Samantha-1.11-13B-GGUF)
- [Samantha-1.11-CodeLlama-34B-GGUF](https://huggingface.co/TheBloke/Samantha-1.11-CodeLlama-34B-GGUF)

## Dev Setup

1. Open mac/FreeChat.xcodeproj
2. Run and fix errors

### Roadmap / TODO (roughly in order):

- [x] Chat with Llama 2 7B without installing anything else
- [x] Try any llama.cpp compatible model
- [x] Change system prompts to modify personas or expertise
- [ ] Download models from within the app (shrink app from 3GB to 10mb, way better for updates)
- [ ] Advanced settings (prompt format, temperature, repeat penalty)
- [ ] Personas - save system prompt / model settings for later and change personas when you create a new conversation
- [ ] Search conversations

### Contributing

Contributions are very welcome. Let's make FreeChat simple and powerful.

### Credits

This project would not be possible without the hard work of:

- Georgi Gerganov for [llama.cpp](https://github.com/ggerganov/llama.cpp)
- Meta for training Llama 2
- Jon Durbin for training Spicyboros, the default model
- TheBloke (Tom Jobbins) for model quantization
- Monica Kogler for the FreeChat logo and uncountable UX consults

Also many thanks to Billy Rennekamp, Elliot Hursh, Tomás Savigliano, Judd Schoenholtz, Alex Farrill for invaluable spitballing sessions.
