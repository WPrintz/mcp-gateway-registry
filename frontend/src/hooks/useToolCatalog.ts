/**
 * Hook for fetching tool catalog from the Virtual MCP API.
 *
 * Provides a list of servers and their available tools for
 * building scope configurations in the IAM Groups form.
 */

import { useState, useEffect, useCallback } from 'react';
import axios from 'axios';


interface ToolEntry {
  tool_name: string;
  server_path: string;
  server_name: string;
  description: string;
  input_schema: Record<string, unknown>;
  available_versions: string[];
}

interface ToolCatalogResponse {
  tools: ToolEntry[];
  total_count: number;
  server_count: number;
  by_server: Record<string, ToolEntry[]>;
}

interface ServerWithTools {
  path: string;
  name: string;
  tools: string[];
}

interface UseToolCatalogReturn {
  servers: ServerWithTools[];
  isLoading: boolean;
  error: string | null;
  refetch: () => Promise<void>;
}


export function useToolCatalog(): UseToolCatalogReturn {
  const [servers, setServers] = useState<ServerWithTools[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchCatalog = useCallback(async () => {
    setIsLoading(true);
    setError(null);

    try {
      const response = await axios.get<ToolCatalogResponse>('/api/virtual/tool-catalog');
      const data = response.data;

      // Transform by_server into array of ServerWithTools
      const serverList: ServerWithTools[] = [];

      for (const [serverPath, tools] of Object.entries(data.by_server || {})) {
        if (tools.length > 0) {
          serverList.push({
            path: serverPath,
            name: tools[0].server_name || serverPath,
            tools: tools.map((t) => t.tool_name),
          });
        }
      }

      // Sort by server name
      serverList.sort((a, b) => a.name.localeCompare(b.name));

      setServers(serverList);
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Failed to fetch tool catalog';
      setError(message);
      setServers([]);
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchCatalog();
  }, [fetchCatalog]);

  return {
    servers,
    isLoading,
    error,
    refetch: fetchCatalog,
  };
}
