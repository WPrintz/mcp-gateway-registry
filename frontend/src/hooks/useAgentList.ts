/**
 * Hook for fetching the list of agents.
 *
 * Provides agent names for scope configuration in IAM Groups form.
 * Only returns name and path - no detailed agent information needed.
 */

import { useState, useEffect, useCallback } from 'react';
import axios from 'axios';


interface AgentBasicInfo {
  name: string;
  path: string;
}

interface AgentListResponse {
  agents: Array<{
    name: string;
    path: string;
    description?: string;
    [key: string]: unknown;
  }>;
}

interface UseAgentListReturn {
  agents: AgentBasicInfo[];
  isLoading: boolean;
  error: string | null;
  refetch: () => Promise<void>;
}


export function useAgentList(): UseAgentListReturn {
  const [agents, setAgents] = useState<AgentBasicInfo[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchAgents = useCallback(async () => {
    setIsLoading(true);
    setError(null);

    try {
      const response = await axios.get<AgentListResponse>('/api/agents');
      const data = response.data;

      // Extract just name and path
      const agentList: AgentBasicInfo[] = (data.agents || []).map((agent) => ({
        name: agent.name,
        path: agent.path,
      }));

      // Sort by name
      agentList.sort((a, b) => a.name.localeCompare(b.name));

      setAgents(agentList);
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Failed to fetch agents';
      setError(message);
      setAgents([]);
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchAgents();
  }, [fetchAgents]);

  return {
    agents,
    isLoading,
    error,
    refetch: fetchAgents,
  };
}
