const API_URL = "http://localhost:8080/chat";
const SUGGESTED_PROMPTS = [
  "What is the status of claim CLM-1001?",
  "Is member MBR-2001 eligible?",
  "What are the benefits for plan PLAN-A1?",
];

const messagesEl = document.getElementById("messages");
const suggestionsEl = document.getElementById("suggestions");
const formEl = document.getElementById("chatForm");
const inputEl = document.getElementById("messageInput");
const sendButtonEl = document.getElementById("sendButton");
const statusEl = document.getElementById("status");
const threadIdLabelEl = document.getElementById("threadIdLabel");

const threadId = generateUuid();
let isSending = false;
let loadingMessageEl = null;

threadIdLabelEl.textContent = threadId;
threadIdLabelEl.title = threadId;

renderSuggestions();
addMessage(
  "assistant",
  "Hello. I can help you review claim status, member eligibility, and plan benefits for this demo."
);
inputEl.focus();

formEl.addEventListener("submit", async (event) => {
  event.preventDefault();
  await handleSend(inputEl.value);
});

async function handleSend(rawMessage) {
  const message = rawMessage.trim();
  if (!message || isSending) {
    return;
  }

  addMessage("user", message);
  formEl.reset();
  setStatus("Assistant is reviewing your request.");
  setLoading(true);

  try {
    const response = await fetch(API_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message,
        thread_id: threadId,
      }),
    });

    if (!response.ok) {
      throw new Error(`Request failed with status ${response.status}.`);
    }

    const payload = await response.json();
    addMessage("assistant", payload.response || "No response received.");
    setStatus("Response received.");
  } catch (error) {
    addMessage(
      "assistant",
      "I couldn't reach the claims API. Make sure the standalone backend is running on http://localhost:8080 and try again."
    );
    setStatus(error.message || "Unable to reach the API.", true);
  } finally {
    setLoading(false);
    inputEl.focus();
  }
}

function renderSuggestions() {
  SUGGESTED_PROMPTS.forEach((prompt) => {
    const button = document.createElement("button");
    button.type = "button";
    button.className = "chip";
    button.textContent = prompt;
    button.addEventListener("click", () => {
      inputEl.value = prompt;
      handleSend(prompt);
    });
    suggestionsEl.appendChild(button);
  });
}

function addMessage(role, text) {
  const messageEl = document.createElement("article");
  messageEl.className = `message ${role}`;

  const bubbleEl = document.createElement("div");
  bubbleEl.className = "bubble";
  bubbleEl.textContent = text;

  messageEl.appendChild(bubbleEl);
  messagesEl.appendChild(messageEl);
  scrollToBottom();
}

function setLoading(loading) {
  isSending = loading;
  inputEl.disabled = loading;
  sendButtonEl.disabled = loading;
  sendButtonEl.textContent = loading ? "Sending..." : "Send";

  suggestionsEl.querySelectorAll(".chip").forEach((chip) => {
    chip.disabled = loading;
  });

  if (loading) {
    loadingMessageEl = document.createElement("article");
    loadingMessageEl.className = "message assistant loading";
    loadingMessageEl.innerHTML = `
      <div class="bubble">
        <span class="typing-dots" aria-hidden="true"><span></span><span></span><span></span></span>
        <span>Working on your request...</span>
      </div>
    `;
    messagesEl.appendChild(loadingMessageEl);
    scrollToBottom();
    return;
  }

  if (loadingMessageEl) {
    loadingMessageEl.remove();
    loadingMessageEl = null;
  }
}

function setStatus(message, isError = false) {
  statusEl.textContent = message;
  statusEl.classList.toggle("error", isError);
}

function scrollToBottom() {
  messagesEl.scrollTop = messagesEl.scrollHeight;
}

function generateUuid() {
  if (window.crypto && typeof window.crypto.randomUUID === "function") {
    return window.crypto.randomUUID();
  }

  return "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g, (char) => {
    const random = Math.floor(Math.random() * 16);
    const value = char === "x" ? random : (random & 0x3) | 0x8;
    return value.toString(16);
  });
}
