/**
 * Hooks for fetching servers and their tools.
 *
 * Fetches all servers from /api/servers with descriptions
 * for use in searchable select components.
 */

import { useState, useEffect, useCallback } from 'react';
import axios from 'axios';


export interface ServerInfo {
  path: string;
  name: string;
  description: string;
}

export interface ToolInfo {
  name: string;
  description: string;
  serverPath: string;
}

interface ServerListResponse {
  servers: Array<{
    path: string;
    server_name?: string;
    name?: string;
    description?: string;
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
  by_server: Record<string, Array<{
    tool_name: string;
    description: string;
  }>>;
}

interface UseServerListReturn {
  servers: ServerInfo[];
  isLoading: boolean;
  error: string | null;
  refetch: () => Promise<void>;
}

interface UseServerToolsReturn {
  tools: ToolInfo[];
  isLoading: boolean;
  error: string | null;
}


/**
 * Hook to fetch all available servers with descriptions.
 */
export function useServerList(): UseServerListReturn {
  const [servers, setServers] = useState<ServerInfo[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchServers = useCallback(async () => {
    setIsLoading(true);
    setError(null);

    try {
      const response = await axios.get<ServerListResponse>('/api/servers');
      const data = response.data;

      const serverList: ServerInfo[] = (data.servers || []).map((s) => ({
        path: s.path,
        name: s.server_name || s.name || s.path,
        description: s.description || '',
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
  const [tools, setTools] = useState<ToolInfo[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    // Don't fetch for empty or wildcard
    if (!serverPath || serverPath === '*') {
      setTools([]);
      setIsLoading(false);
      return;
    }

    const fetchTools = async () => {
      setIsLoading(true);
      setError(null);

      try {
        const response = await axios.get<ToolCatalogResponse>(
          `/api/tool-catalog?server_path=${encodeURIComponent(serverPath)}`
        );
        const data = response.data;

        // Extract tools from the response
        const toolList: ToolInfo[] = (data.tools || []).map((t) => ({
          name: t.tool_name,
          description: t.description || '',
          serverPath: t.server_path,
        }));

        // Sort by name
        toolList.sort((a, b) => a.name.localeCompare(b.name));

        setTools(toolList);
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
