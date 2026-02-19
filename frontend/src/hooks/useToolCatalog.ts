/**
 * Hook for fetching servers and their tools.
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

interface ServerListResponse {
  servers: Array<{
    path: string;
    server_name?: string;
    name?: string;
    description?: string;
    [key: string]: unknown;
  }>;
}

interface UseServerListReturn {
  servers: ServerInfo[];
  isLoading: boolean;
  error: string | null;
  refetch: () => Promise<void>;
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
