# Local AI Infrastructure Bridge 🚀

This project demonstrates a hybrid AI development environment, connecting a **macOS client** (MacBook Air) to a high-performance **Windows GPU Server** to run Large Language Models (LLMs) locally.

## 🛠 System Architecture
The setup is designed to offload heavy AI computations to a dedicated GPU while maintaining a seamless development experience on macOS:

* **Inference Server (Windows)**: Runs LM Studio as a local API server and provides the `lms` CLI for model management.
* **Network Layer**: Secure communication via an SSH tunnel over a Tailscale private network.
* **Development Client (macOS)**: Python 3.x environment with isolated dependencies.

## 🚀 How It Works
The workflow is automated using ZSH aliases and Python scripts:
1. **Wake-on-LAN**: The `wake-pc` command boots the Windows server remotely.
2. **Tunneling**: The `ai` alias establishes a secure bridge between `localhost:1234` on Mac and the Windows server.
3. **Verification**: A Python script (`script.py`) validates the connection and lists available models via the API.

## 📁 Project Structure
* `script.py`: A Python utility using the `requests` library to communicate with the LM Studio API.
* `.venv/`: A virtual environment ensuring isolated and reproducible dependency management.
* `requirements.txt`: List of Python packages required for the project.

## 📈 Proven Results
As shown in the output below, the system successfully identifies remote models, such as `meta-llama-3.1-8b-instruct`, and allows for direct terminal-based interaction via `lms chat`.

> **Terminal Output:**
<img width="370" height="88" alt="image" src="https://github.com/user-attachments/assets/52759264-0597-4568-8c76-18171777f70b" />


---
*Developed for educational purposes, focusing on system engineering, automation, and local AI integration.*
