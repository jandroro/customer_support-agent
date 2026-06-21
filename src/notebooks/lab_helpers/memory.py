from bedrock_agentcore.memory import MemoryClient
from bedrock_agentcore.memory.constants import StrategyType
from .aws_clients import (
    REGION,
    agentcore_client,
    agentcore_control_client,
)
from .utils import get_ssm_parameter, put_ssm_parameter


# =====================================================
# MEMORY SETUP
# =====================================================

# Setup the memory name
memory_name = "CustomerSupportMemory"

# Memory Client Setup:
memory_client = MemoryClient(region_name=REGION)

# Override clients with ones that use the correct session/profile
memory_client.gmcp_client = agentcore_control_client
memory_client.gmdp_client = agentcore_client


# =====================================================
# LOCAL METHODS
# =====================================================

def create_or_get_memory_resource():
    try:
        memory_id = get_ssm_parameter("/app/customersupport/agentcore/memory_id")
        memory_client.gmcp_client.get_memory(memoryId=memory_id)
        return memory_id
    except Exception:
        try:
            strategies = [
                {
                    StrategyType.USER_PREFERENCE.value: {
                        "name": "CustomerPreferences",
                        "description": "Captures customer preferences and behavior",
                        "namespaces": ["support/customer/{actorId}/preferences"],
                    }
                },
                {
                    StrategyType.SEMANTIC.value: {
                        "name": "CustomerSupportSemantic",
                        "description": "Stores facts from conversations",
                        "namespaces": ["support/customer/{actorId}/semantic"],
                    }
                },
            ]
            
            print("Creating AgentCore Memory resources. This can a couple of minutes..")
            # *** AGENTCORE MEMORY USAGE *** - Create memory resource with semantic and user_pref strategy
            response = memory_client.create_memory_and_wait(
                name=memory_name,
                description="Customer support agent memory",
                strategies=strategies,
                event_expiry_days=90,  # Memories expire after 90 days
                enable_observability=False,
            )
            
            memory_id = response["id"]
            try:
                put_ssm_parameter("/app/customersupport/agentcore/memory_id", memory_id)
            except Exception as e:
                raise e
            return memory_id
        except Exception:
            return None