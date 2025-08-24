# ⸸ HAIL SATAN - Local AI Setup Guide ⸸

## Local AI Setup with Ollama (FREE & PRIVATE! ⸸)

### 1. **Install Ollama**:
   ```bash
   # Install Ollama
   curl -fsSL https://ollama.ai/install.sh | sh
   
   # Or on Arch Linux:
   # sudo pacman -S ollama
   
   # Or on Ubuntu/Debian:
   # curl -fsSL https://ollama.ai/install.sh | sh
   ```

### 2. **Download Local AI Models**:
   ```bash
   # Start Ollama service
   ollama serve
   
   # In another terminal, download models:
   ollama pull codellama:7b        # Code generation (smaller, faster)
   ollama pull llama3.1:8b         # General purpose (good balance)
   ollama pull deepseek-coder:6.7b # Code-focused (excellent for programming)
   ollama pull codeqwen:7b         # Alternative code model
   
   # Optional: Larger models (if you have good hardware)
   # ollama pull codellama:13b
   # ollama pull llama3.1:70b
   ```

### 3. **Install Neovim plugins**:
   ```bash
   nvim
   # In Neovim, run:
   :Lazy sync
   ```

### 4. **Test Local AI**:
   ```bash
   # In Neovim, try:
   # <Space>al (Local AI Generate)
   # <Space>ac (Switch models)
   # <Space>am (Local AI Chat)
   ```

## GitHub Copilot Setup (Paid Service)

1. **Install the plugins** (already configured):
   ```bash
   nvim
   # In Neovim, run:
   :Lazy sync
   ```

2. **Authenticate with GitHub Copilot**:
   ```bash
   # In Neovim, run:
   :Copilot auth
   ```
   - This will open a browser for GitHub authentication
   - Follow the instructions to link your GitHub account
   - You need an active GitHub Copilot subscription

3. **Verify Copilot is working**:
   ```bash
   # In Neovim, run:
   :Copilot status
   ```

## AI Keymaps (with leader key: Space)

### Local AI Models 🤖 (Ollama)

#### **Gen.nvim (Simple Local AI):**
- `<leader>al` - Generate text with local AI
- `<leader>ac` - Switch between local models
- `<leader>aE` - Enhance code with local AI
- `<leader>ax` - Fix code with local AI
- `<leader>ad` - Generate documentation with local AI

#### **Ollama.nvim (Advanced):**
- `<leader>ao` - Ollama prompt
- `<leader>aO` - Generate code with Ollama

#### **Model.nvim (Chat Interface):**
- `<leader>am` - Local AI chat interface
- `<leader>ar` - Code review with local AI (visual mode)
- `<leader>ae` - Explain code with local AI (visual mode)
- `<leader>aF` - Fix code with local AI (visual mode)
- `<leader>aD` - Generate docs with local AI (visual mode)
- `<leader>aS` - Satanic code rewrite 👹 (visual mode)

### GitHub Copilot (Insert Mode)
- `Ctrl+J` - Accept Copilot suggestion
- `Ctrl+L` - Accept Copilot word
- `Ctrl+H` - Previous Copilot suggestion  
- `Ctrl+K` - Next Copilot suggestion
- `Ctrl+\` - Dismiss Copilot suggestion

### Copilot Chat
- `<leader>aa` - Quick AI chat
- `<leader>ab` - Chat with current buffer
- `<leader>av` - Chat with visual selection
- `<leader>ai` - Inline chat with selection
- `<leader>af` - Fix diagnostic with AI
- `<leader>at` - Toggle Copilot Chat window
- `<leader>ah` - Show Copilot help
- `<leader>ap` - Show prompt actions
- `<leader>ar` - Reset chat history
- `<leader>aq` - Close chat

### Custom Satanic Prompts 👹
- `<leader>aS` - Rewrite code with occult theme (local AI)
- `<leader>aD` - Debug (summon bugs) 
- `<leader>aR` - Dark refactor

### Local AI Usage Examples

#### **Model Selection:**
1. Press `<leader>ac` to switch models
2. Choose from:
   - `codellama:7b` - Fast, good for code completion
   - `llama3.1:8b` - Balanced for general tasks
   - `deepseek-coder:6.7b` - Excellent for programming
   - `codeqwen:7b` - Alternative coding model

#### **Code Review:**
1. Select code in visual mode
2. Press `<leader>ar` for AI code review
3. Get suggestions for improvement

#### **Code Explanation:**
1. Select code in visual mode  
2. Press `<leader>ae` for detailed explanation
3. Understand complex code sections

## System Requirements

### **Minimum Requirements:**
- **RAM**: 8GB (for 7B models)
- **Storage**: 4-6GB per model
- **CPU**: Modern multi-core processor

### **Recommended:**
- **RAM**: 16GB+ (for multiple models)
- **Storage**: 50GB+ for model collection
- **GPU**: NVIDIA GPU with CUDA (optional, for faster inference)

### **Model Sizes:**
- `codellama:7b` - ~4GB
- `llama3.1:8b` - ~4.7GB  
- `deepseek-coder:6.7b` - ~3.8GB
- `codeqwen:7b` - ~4GB

## Troubleshooting

### Ollama not working:
1. **Check service**: `ollama list`
2. **Start service**: `ollama serve`
3. **Check models**: `ollama list`
4. **Test model**: `ollama run codellama:7b "Hello"`

### Model download issues:
1. **Check space**: `df -h`
2. **Retry download**: `ollama pull codellama:7b`
3. **Check network**: `ping ollama.ai`

### Neovim integration issues:
1. **Check Ollama running**: `curl http://localhost:11434/api/tags`
2. **Reload plugins**: `:Lazy reload gen.nvim`
3. **Check logs**: `:messages`

### Performance optimization:
1. **Use smaller models** for faster responses
2. **Close unused models**: `ollama stop model_name`
3. **Monitor resources**: `htop` or `nvidia-smi` (with GPU)

### Copilot not working:
1. Check authentication: `:Copilot status`
2. Re-authenticate: `:Copilot auth`
3. Check your GitHub subscription

## Why Local AI? 🔥

### **Privacy Benefits:**
- ✅ **Complete privacy** - code never leaves your machine
- ✅ **No API keys** required for local models
- ✅ **No internet dependency** (after download)
- ✅ **No usage limits** or rate limiting
- ✅ **Full control** over model behavior

### **Cost Benefits:**
- ✅ **FREE after initial setup**
- ✅ **No subscription fees**
- ✅ **No per-token charges**
- ✅ **Unlimited usage**

### **Performance:**
- ✅ **Fast responses** (depends on hardware)
- ✅ **No network latency**
- ✅ **Available offline**
- ✅ **Multiple models** for different tasks

### **Perfect for:**
- Sensitive/proprietary code
- Learning and experimentation
- Offline development
- Cost-conscious developers
- Privacy-focused workflows

---

**May the LOCAL forces of AI guide your coding in complete privacy! ⸸🤖👹** 