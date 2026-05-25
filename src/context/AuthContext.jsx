import { createContext, useContext, useState, useEffect } from 'react';
import * as api from '../lib/api';

const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  const [user, setUser]       = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const token = localStorage.getItem('qci_token');
    if (token) {
      api.getMe()
        .then(({ user }) => setUser(user))
        .catch(() => localStorage.removeItem('qci_token'))
        .finally(() => setLoading(false));
    } else {
      setLoading(false);
    }
  }, []);

  async function login(email, password) {
    const { token, user } = await api.login(email, password);
    localStorage.setItem('qci_token', token);
    setUser(user);
    return user;
  }

  function logout() {
    localStorage.removeItem('qci_token');
    setUser(null);
  }

  return (
    <AuthContext.Provider value={{ user, setUser, login, logout, loading }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() { return useContext(AuthContext); }
