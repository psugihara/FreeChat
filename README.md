<p align="center" width="100%">
<img width="120" alt="FreeChat app icon" src="https://github.com/psugihara/FreeChat/assets/282016/26be9d7a-fc18-476d-b0eb-13c4a37cfc54">
</p>

<h1 align="center">FreeChat</h1>

Chat with LLMs on your Mac without installing any other software. Every conversation is saved locally, all conversations happen offline.

- Customize persona and expertise by changing the system prompt
- Try any llama.cpp compatible model
- No internet connection required, all local (with the option to connect to a remote model)

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
- Local first. Core functionality should not require an internet connection.
- No conversation tracking. Talk about whatever you want with FreeChat, just like Notes.
- Open source. What's the point of running local AI if you can't audit that it's actually running locally?

### Upgrade your models

Once you're up and running, it's fun to try different models in FreeChat. The AI training community is releasing new models basically every day. FreeChat is compatible with any gguf formatted model that [llama.cpp](https://github.com/ggerganov/llama.cpp) works with.

Models are usually named with their parameter count (e.g. 7B) and are formatted with different levels of lossy compression applied (quantization). The general rule of thumb is that models with more parameters tend to be slower and wiser and more quantization makes it dumber.

To find models, try [Hugging Face](https://huggingface.co/models?sort=trending&search=gguf). Most models have a linked "model card" by the author that discusses its training and abilities.

## Dev Setup

1. Open mac/FreeChat.xcodeproj
2. Run and fix errors

### Roadmap / TODO (roughly in order):

- [x] Chat with Llama 3 without installing anything else
- [x] Try any llama.cpp compatible model
- [x] Change system prompts to modify personas or expertise
- [x] Download models from within the app (shrink app from 3GB to 10mb, way better for updates)
- [x] Advanced settings (prompt format, temperature, repeat penalty)
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
