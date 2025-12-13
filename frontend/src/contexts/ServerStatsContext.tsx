import React, { createContext, useContext, useState, useEffect, useCallback, ReactNode } from 'react';
import axios from 'axios';

interface Server {
  name: string;
  path: string;
  description?: string;
  official?: boolean;
  enabled: boolean;
  tags?: string[];
  last_checked_time?: string;
  usersCount?: number;
  rating?: number;
  status?: 'healthy' | 'healthy-auth-expired' | 'unhealthy' | 'unknown';
  num_tools?: number;
}

interface ServerStats {
  total: number;
  enabled: number;
  disabled: number;
  withIssues: number;
}

interface ServerStatsContextType {
  stats: ServerStats;
  servers: Server[];
  setServers: React.Dispatch<React.SetStateAction<Server[]>>;
  activeFilter: string;
  setActiveFilter: (filter: string) => void;
  loading: boolean;
  error: string | null;
  refreshData: () => Promise<void>;
}

const ServerStatsContext = createContext<ServerStatsContextType | undefined>(undefined);

// Helper function to map backend health status to frontend status
const mapHealthStatus = (healthStatus: string): 'healthy' | 'unhealthy' | 'unknown' => {
  if (!healthStatus || healthStatus === 'unknown') return 'unknown';
  if (healthStatus === 'healthy') return 'healthy';
  if (healthStatus.includes('unhealthy') || healthStatus.includes('error') || healthStatus.includes('timeout')) return 'unhealthy';
  return 'unknown';
};

export const ServerStatsProvider: React.FC<{ children: ReactNode }> = ({ children }) => {
  const [stats, setStats] = useState<ServerStats>({
    total: 0,
    enabled: 0,
    disabled: 0,
    withIssues: 0,
  });
  const [servers, setServers] = useState<Server[]>([]);
  const [activeFilter, setActiveFilter] = useState<string>('all');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchData = useCallback(async () => {
    try {
      setLoading(true);
      setError(null);
      
      const response = await axios.get('/api/servers');
      const responseData = response.data || {};
      const serversList = responseData.servers || [];
      
      const transformedServers: Server[] = serversList.map((serverInfo: any) => ({
        name: serverInfo.display_name || 'Unknown Server',
        path: serverInfo.path,
        description: serverInfo.description || '',
        official: serverInfo.is_official || false,
        enabled: serverInfo.is_enabled !== undefined ? serverInfo.is_enabled : false,
        tags: serverInfo.tags || [],
        last_checked_time: serverInfo.last_checked_iso,
        usersCount: 0,
        rating: serverInfo.num_stars || 0,
        status: mapHealthStatus(serverInfo.health_status || 'unknown'),
        num_tools: serverInfo.num_tools || 0
      }));
      
      setServers(transformedServers);
      
      // Calculate stats
      let total = 0;
      let enabled = 0;
      let disabled = 0;
      let withIssues = 0;
      
      transformedServers.forEach((server) => {
        total++;
        if (server.enabled) {
          enabled++;
        } else {
          disabled++;
        }
        if (server.status === 'unhealthy') {
          withIssues++;
        }
      });
      
      setStats({ total, enabled, disabled, withIssues });
    } catch (err: any) {
      console.error('Failed to fetch server data:', err);
      setError(err.response?.data?.detail || 'Failed to fetch server data');
      setServers([]);
      setStats({ total: 0, enabled: 0, disabled: 0, withIssues: 0 });
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchData();
  }, [fetchData]);

  return (
    <ServerStatsContext.Provider value={{
      stats,
      servers,
      setServers,
      activeFilter,
      setActiveFilter,
      loading,
      error,
      refreshData: fetchData,
    }}>
      {children}
    </ServerStatsContext.Provider>
  );
};

export const useServerStats = (): ServerStatsContextType => {
  const context = useContext(ServerStatsContext);
  if (context === undefined) {
    throw new Error('useServerStats must be used within a ServerStatsProvider');
  }
  return context;
};
