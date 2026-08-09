from fastapi import Depends, FastAPI, Header
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from langchain.chat_models import init_chat_model
from langchain.agents import create_agent
from langgraph.checkpoint.memory import InMemorySaver

app = FastAPI()
checkpointer = InMemorySaver()


class UserProfile(BaseModel):
    user_id: str
    tier: str
    language: str


async def get_verified_user(
    x_user_id: str = Header(..., alias="X-User-Id"),
    x_user_tier: str = Header(..., alias="X-User-Tier"),
    x_user_lang: str = Header(default="English", alias="X-User-Lang"),
) -> UserProfile:
    return UserProfile(user_id=x_user_id, tier=x_user_tier, language=x_user_lang)


def get_agent_for_user(user: UserProfile):
    model_name = (
        "anthropic:claude-3-5-sonnet-latest"
        if user.tier in ["pro", "enterprise"]
        else "anthropic:claude-3-haiku-20240307"
    )
    model = init_chat_model(model_name, temperature=0.1)
    prompt = f"You are a helpful AI. Reply in {user.language}."
    return create_agent(model=model, tools=[], system_prompt=prompt, checkpointer=checkpointer)


async def stream_generator(agent, question: str, thread_id: str):
    try:
        async for event in agent.astream_events(
            {"messages": [{"role": "user", "content": question}]},
            config={"configurable": {"thread_id": thread_id}},
            version="v1",
        ):
            if event["event"] == "on_chat_model_stream" and event["data"]["chunk"].content:
                yield f"data: {event['data']['chunk'].content}\n\n"

        yield "data: [DONE]\n\n"
    except Exception as exc:
        yield f"data: [ERROR] {str(exc)}\n\n"


@app.get("/api/v1/chat/stream")
async def chat_stream(
    thread_id: str,
    question: str,
    user: UserProfile = Depends(get_verified_user),
):
    agent = get_agent_for_user(user)
    return StreamingResponse(
        stream_generator(agent, question, thread_id),
        media_type="text/event-stream",
    )
