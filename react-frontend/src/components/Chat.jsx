import React, { useState } from "react";

export default function Chat({ authToken = "test_token", userId = "user_123" }) {
  const [messages, setMessages] = useState([]);
  const [input, setInput] = useState("");
  const [isStreaming, setIsStreaming] = useState(false);

  const backendUrl = import.meta.env.VITE_BACKEND_URL || "http://localhost:3000";

  const handleSend = async () => {
    if (!input.trim() || isStreaming) {
      return;
    }

    const userMsg = { role: "user", content: input };

    setMessages((prev) => [...prev, userMsg, { role: "assistant", content: "" }]);
    setInput("");
    setIsStreaming(true);

    const threadId = `session_${userId}`;

    try {
      const response = await fetch(`${backendUrl}/api/v1/chat/stream`, {
        method: "POST",
        headers: {
          Authorization: "Bearer " + authToken,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          thread_id: threadId,
          question: userMsg.content,
        }),
      });

      if (!response.ok || !response.body) {
        throw new Error(`Request failed with status ${response.status}`);
      }

      const reader = response.body.getReader();
      const decoder = new TextDecoder();
      let done = false;

      while (!done) {
        const { value, done: readerDone } = await reader.read();
        done = readerDone;

        if (value) {
          const chunk = decoder.decode(value, { stream: true });
          const lines = chunk.split("\n");

          for (const line of lines) {
            if (!line.startsWith("data: ")) {
              continue;
            }

            const text = line.replace("data: ", "");

            if (text === "[DONE]") {
              done = true;
              break;
            }

            if (text.startsWith("[ERROR]")) {
              throw new Error(text);
            }

            setMessages((prev) => {
              const newMessages = [...prev];
              newMessages[newMessages.length - 1] = {
                ...newMessages[newMessages.length - 1],
                content: newMessages[newMessages.length - 1].content + text,
              };
              return newMessages;
            });
          }
        }
      }
    } catch (error) {
      console.error("Fetch error:", error);
    } finally {
      setIsStreaming(false);
    }
  };

  return (
    <div>
      <div>
        {messages.map((message, index) => (
          <div key={`${message.role}-${index}`}>
            <strong>{message.role}:</strong> {message.content}
          </div>
        ))}
      </div>
      <input value={input} onChange={(event) => setInput(event.target.value)} />
      <button type="button" onClick={handleSend} disabled={isStreaming}>
        {isStreaming ? "Streaming..." : "Send"}
      </button>
    </div>
  );
}
