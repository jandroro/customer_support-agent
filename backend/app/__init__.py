"""Customer Support Agent backend.

A thin FastAPI service that bridges the Next.js frontend and the Bedrock
AgentCore Runtime: it handles Cognito authentication (shared service identity
and per-user register/login/refresh against MCPServerPool) and proxies chat
messages to the deployed AgentCore Runtime.
"""
