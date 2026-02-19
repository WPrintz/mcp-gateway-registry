/**
 * Hook for fetching servers and their tools.
 *
 * Fetches all servers from /api/servers, then fetches tools
 * from the tool catalog for the selected server.
 */

import { useState, useEffect, useCallback } from 'react';
import axios from 'axios';


interface ServerBasicInfo {
  path: string;
  name: string;
}

interface ServerListResponse {
  servers: Array<{
    path: string;
    server_name?: string;
    name?: string;
    [key: string]: unknown;
  }>;
}

interface ToolCatalogResponse {
  tools: Array<{
    tool_name: string;
    server_path: string;
    server_name: string;
    description: string;
  }>;
  by_server: Record<string, Array<{ tool_name: string }>>;
}

interface UseServerListReturn {
  servers: ServerBasicInfo[];
  isLoading: boolean;
  error: string | null;
  refetch: () => Promise<void>;
}

interface UseServerToolsReturn {
  tools: string[];
  isLoading: boolean;
  error: string | null;
}


/**
 * Hook to fetch all available servers.
 */
export function useServerList(): UseServerListReturn {
  const [servers, setServers] = useState<ServerBasicInfo[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchServers = useCallback(async () => {
    setIsLoading(true);
    setError(null);

    try {
      const response = await axios.get<ServerListResponse>('/api/servers');
      const data = response.data;

      const serverList: ServerBasicInfo[] = (data.servers || []).map((s) => ({
        path: s.path,
        name: s.server_name || s.name || s.path,
      }));

      // Sort by name
      serverList.sort((a, b) => a.name.localeCompare(b.name));

      setServers(serverList);
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Failed to fetch servers';
      setError(message);
      setServers([]);
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchServers();
  }, [fetchServers]);

  return {
    servers,
    isLoading,
    error,
    refetch: fetchServers,
  };
}


/**
 * Hook to fetch tools for a specific server.
 * Returns empty array if serverPath is empty or '*'.
 */
export function useServerTools(serverPath: string): UseServerToolsReturn {
  const [tools, setTools] = useState<string[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    // Don't fetch for empty or wildcard
    if (!serverPath || serverPath === '*') {
      setTools([]);
      return;
    }

    const fetchTools = async () => {
      setIsLoading(true);
      setError(null);

      try {
        const response = await axios.get<ToolCatalogResponse>(
          `/api/virtual/tool-catalog?server_path=${encodeURIComponent(serverPath)}`
        );
        const data = response.data;

        // Extract tool names from by_server or tools array
        const serverTools = data.by_server?.[serverPath] || [];
        const toolNames = serverTools.map((t) => t.tool_name);

        setTools(toolNames);
      } catch (err) {
        const message = err instanceof Error ? err.message : 'Failed to fetch tools';
        setError(message);
        setTools([]);
      } finally {
        setIsLoading(false);
      }
    };

    fetchTools();
  }, [serverPath]);

  return {
    tools,
    isLoading,
    error,
  };
}


// Keep backward compatibility - alias for useServerList
export function useToolCatalog() {
  const { servers, isLoading, error, refetch } = useServerList();
  return {
    servers: servers.map((s) => ({ ...s, tools: [] as string[] })),
    isLoading,
    error,
    refetch,
  };
}
