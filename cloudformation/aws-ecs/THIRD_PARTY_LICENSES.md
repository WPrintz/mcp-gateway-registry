# Third-Party Licenses

This workshop uses the following third-party software components. All licenses
permit use in this workshop context.

## Container Base Images

| Component | Version | License | URL |
|-----------|---------|---------|-----|
| Python | 3.12-slim | PSF License | https://www.python.org/psf/license/ |
| Node.js | 20-slim | MIT | https://github.com/nodejs/node/blob/main/LICENSE |
| Grafana OSS | 12.3.1 | AGPL-3.0 | https://github.com/grafana/grafana/blob/main/LICENSE |
| Keycloak | 23.0 | Apache-2.0 | https://github.com/keycloak/keycloak/blob/main/LICENSE.txt |
| AWS Distro for OpenTelemetry (ADOT) | latest | Apache-2.0 | https://github.com/aws-observability/aws-otel-collector/blob/main/LICENSE |

## Core Infrastructure

| Component | License | URL |
|-----------|---------|-----|
| Nginx | BSD-2-Clause | https://nginx.org/LICENSE |
| nginx-extras (Lua module) | BSD-2-Clause | https://github.com/openresty/lua-nginx-module/blob/master/LICENSE |
| lua-cjson | MIT | https://github.com/openresty/lua-cjson/blob/master/LICENSE |

## Python Packages - Registry and Auth Services

| Package | License | URL |
|---------|---------|-----|
| FastAPI | MIT | https://github.com/fastapi/fastapi/blob/master/LICENSE |
| Uvicorn | BSD-3-Clause | https://github.com/encode/uvicorn/blob/master/LICENSE.md |
| Pydantic | MIT | https://github.com/pydantic/pydantic/blob/main/LICENSE |
| httpx | BSD-3-Clause | https://github.com/encode/httpx/blob/master/LICENSE.md |
| Jinja2 | BSD-3-Clause | https://github.com/pallets/jinja/blob/main/LICENSE.txt |
| PyJWT | MIT | https://github.com/jpadilla/pyjwt/blob/master/LICENSE |
| python-jose | MIT | https://github.com/mpdavis/python-jose/blob/master/LICENSE |
| cryptography | Apache-2.0 / BSD-3-Clause | https://github.com/pyca/cryptography/blob/main/LICENSE |
| Motor | Apache-2.0 | https://github.com/mongodb/motor/blob/master/LICENSE |
| PyMongo | Apache-2.0 | https://github.com/mongodb/mongo-python-driver/blob/master/LICENSE |
| boto3 | Apache-2.0 | https://github.com/boto/boto3/blob/develop/LICENSE |
| requests | Apache-2.0 | https://github.com/psf/requests/blob/main/LICENSE |
| aiohttp | Apache-2.0 | https://github.com/aio-libs/aiohttp/blob/master/LICENSE.txt |
| PyYAML | MIT | https://github.com/yaml/pyyaml/blob/main/LICENSE |
| itsdangerous | BSD-3-Clause | https://github.com/pallets/itsdangerous/blob/main/LICENSE.txt |
| python-dotenv | BSD-3-Clause | https://github.com/theskumar/python-dotenv/blob/main/LICENSE |

## AI/ML and Embeddings

| Package | License | URL |
|---------|---------|-----|
| sentence-transformers | Apache-2.0 | https://github.com/UKPLab/sentence-transformers/blob/master/LICENSE |
| PyTorch | BSD-3-Clause | https://github.com/pytorch/pytorch/blob/main/LICENSE |
| FAISS (faiss-cpu) | MIT | https://github.com/facebookresearch/faiss/blob/main/LICENSE |
| scikit-learn | BSD-3-Clause | https://github.com/scikit-learn/scikit-learn/blob/main/COPYING |
| huggingface-hub | Apache-2.0 | https://github.com/huggingface/huggingface_hub/blob/main/LICENSE |
| LiteLLM | MIT | https://github.com/BerriAI/litellm/blob/main/LICENSE |

## MCP and Agent Frameworks

| Package | License | URL |
|---------|---------|-----|
| mcp (Model Context Protocol) | MIT | https://github.com/modelcontextprotocol/python-sdk/blob/main/LICENSE |
| FastMCP | MIT | https://github.com/jlowin/fastmcp/blob/main/LICENSE |
| langchain-mcp-adapters | MIT | https://github.com/langchain-ai/langchain-mcp-adapters/blob/main/LICENSE |
| LangGraph | MIT | https://github.com/langchain-ai/langgraph/blob/main/LICENSE |
| langchain-aws | MIT | https://github.com/langchain-ai/langchain-aws/blob/main/LICENSE |
| langchain-anthropic | MIT | https://github.com/langchain-ai/langchain/blob/master/LICENSE |
| strands-agents | Apache-2.0 | https://github.com/strands-agents/sdk-python/blob/main/LICENSE |

## Observability

| Package | License | URL |
|---------|---------|-----|
| OpenTelemetry Python SDK | Apache-2.0 | https://github.com/open-telemetry/opentelemetry-python/blob/main/LICENSE |
| opentelemetry-exporter-prometheus | Apache-2.0 | https://github.com/open-telemetry/opentelemetry-python-contrib/blob/main/LICENSE |

## Security Scanning

| Package | License | URL |
|---------|---------|-----|
| Bandit | Apache-2.0 | https://github.com/PyCQA/bandit/blob/main/LICENSE |
| cisco-ai-a2a-scanner | Apache-2.0 | https://github.com/cisco-ai-defense/a2a-scanner/blob/main/LICENSE |

## Frontend (React UI)

| Package | License | URL |
|---------|---------|-----|
| React | MIT | https://github.com/facebook/react/blob/main/LICENSE |
| React Router | MIT | https://github.com/remix-run/react-router/blob/main/LICENSE.md |
| Tailwind CSS | MIT | https://github.com/tailwindlabs/tailwindcss/blob/master/LICENSE |
| Headless UI | MIT | https://github.com/tailwindlabs/headlessui/blob/main/LICENSE |
| Heroicons | MIT | https://github.com/tailwindlabs/heroicons/blob/master/LICENSE |
| Axios | MIT | https://github.com/axios/axios/blob/v1.x/LICENSE |
| TypeScript | Apache-2.0 | https://github.com/microsoft/TypeScript/blob/main/LICENSE.txt |

## Shell Tools (installed at runtime)

| Tool | License | URL |
|------|---------|-----|
| jq | MIT | https://github.com/jqlang/jq/blob/master/COPYING |
| curl | MIT/X | https://curl.se/docs/copyright.html |
| tmux | ISC | https://github.com/tmux/tmux/blob/master/COPYING |

---

## License Compatibility Notes

**Grafana OSS (AGPL-3.0):** This workshop deploys unmodified Grafana OSS as a
containerized service. The AGPL-3.0 copyleft provisions apply to modifications
of Grafana source code distributed as a network service. Since the workshop
uses an unmodified upstream container image and does not distribute modified
Grafana source, workshop use is compliant. Custom Grafana dashboard JSON
provisioning files are configuration, not derivative works.

**All other components** use permissive licenses (MIT, BSD, Apache-2.0, ISC,
PSF) that allow unrestricted use in workshop and educational contexts.
