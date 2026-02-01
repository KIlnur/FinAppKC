import { useAuth } from 'react-oidc-context'
import { useState, useEffect, useCallback } from 'react'

// Keycloak URLs
const KEYCLOAK_BASE = 'http://localhost:8080'
const REALM = 'finapp'
const CLIENT_ID = 'finapp-web'

// Account API base URL
const ACCOUNT_API = `${KEYCLOAK_BASE}/realms/${REALM}/account`

// Action URL - triggers Keycloak required action flow
const getActionUrl = (action: string) => {
  const redirectUri = encodeURIComponent(window.location.origin)
  return `${KEYCLOAK_BASE}/realms/${REALM}/protocol/openid-connect/auth?client_id=${CLIENT_ID}&redirect_uri=${redirectUri}&response_type=code&scope=openid&kc_action=${action}`
}

// Generate SHA-256 hash for broker link (Base64URL encoded)
async function generateBrokerLinkHash(nonce: string, sessionId: string, clientId: string, provider: string): Promise<string> {
  const data = nonce + sessionId + clientId + provider
  const encoder = new TextEncoder()
  const hashBuffer = await crypto.subtle.digest('SHA-256', encoder.encode(data))
  const hashArray = new Uint8Array(hashBuffer)
  // Convert to Base64URL
  const base64 = btoa(String.fromCharCode(...hashArray))
  return base64.replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')
}

// Generate random nonce
function generateNonce(): string {
  const array = new Uint8Array(16)
  crypto.getRandomValues(array)
  return Array.from(array, b => b.toString(16).padStart(2, '0')).join('')
}

// Types
interface Session {
  id: string
  ipAddress: string
  started: number
  lastAccess: number
  expires: number
  browser: string
  current: boolean
  clients: { clientId: string; clientName: string }[]
}

interface LinkedAccount {
  providerAlias: string
  providerName: string
  connected: boolean
  linkedUsername?: string
  social?: boolean
  socialLinkUrl?: string
}

interface CredentialMetadata {
  credential: {
    id: string
    type: string
    userLabel?: string
    createdDate?: number
    credentialData?: string
  }
}

interface CredentialContainer {
  type: string
  category: string
  displayName: string
  removeable: boolean
  createAction?: string
  updateAction?: string
  userCredentialMetadatas: CredentialMetadata[]
}

// Flattened credential for UI
interface Credential {
  id: string
  type: string
  userLabel?: string
  createdDate?: number
}

function App() {
  const auth = useAuth()

  if (auth.isLoading) {
    return (
      <div className="loading">
        <div className="spinner"></div>
        Loading...
      </div>
    )
  }

  if (auth.error) {
    return (
      <div className="login-container">
        <div className="login-card">
          <h1>Error</h1>
          <p>{auth.error.message}</p>
          <button className="btn btn-primary" onClick={() => auth.signinRedirect()}>
            Try Again
          </button>
        </div>
      </div>
    )
  }

  if (!auth.isAuthenticated) {
    return <LoginPage onLogin={() => auth.signinRedirect()} />
  }

  return <Dashboard auth={auth} />
}

function LoginPage({ onLogin }: { onLogin: () => void }) {
  return (
    <div className="login-container">
      <div className="login-card">
        <img src="/logo.svg" alt="FinApp" />
        <h1>FinApp</h1>
        <p>Enterprise Identity Platform</p>
        <button className="btn btn-primary" onClick={onLogin}>
          Sign In
        </button>
      </div>
    </div>
  )
}

function Dashboard({ auth }: { auth: ReturnType<typeof useAuth> }) {
  const [activeTab, setActiveTab] = useState<'profile' | 'security' | 'token'>('profile')
  
  const user = auth.user
  const profile = user?.profile
  const accessToken = user?.access_token
  
  // Extract claims
  const claims = {
    sub: profile?.sub,
    email: profile?.email,
    email_verified: profile?.email_verified,
    name: profile?.name,
    preferred_username: profile?.preferred_username,
    given_name: profile?.given_name,
    family_name: profile?.family_name,
    roles: (profile as any)?.realm_access?.roles || [],
    groups: (profile as any)?.groups || [],
    phone: (profile as any)?.phone,
    department: (profile as any)?.department,
    employee_id: (profile as any)?.employee_id,
    merchant_id: (profile as any)?.merchant_id,
  }

  const getPrimaryRole = () => {
    if (claims.roles.includes('admin')) return 'Administrator'
    if (claims.roles.includes('agent')) return 'Agent'
    if (claims.roles.includes('merchant')) return 'Merchant'
    return 'User'
  }

  const getRoleBadgeClass = (role: string) => {
    if (role === 'admin') return 'role-badge admin'
    if (role === 'agent') return 'role-badge agent'
    if (role === 'merchant') return 'role-badge merchant'
    return 'role-badge'
  }

  return (
    <div className="app">
      <header className="header">
        <a href="/" className="logo">
          <img src="/logo.svg" alt="" />
          FinApp
        </a>
        <div className="user-menu">
          <div className="user-info">
            <div className="user-name">{claims.name || claims.preferred_username}</div>
            <div className="user-role">{getPrimaryRole()}</div>
          </div>
          <button className="btn btn-danger" onClick={() => auth.signoutRedirect()}>
            Logout
          </button>
        </div>
      </header>

      <main className="main">
        <div className="tabs">
          <button 
            className={`tab ${activeTab === 'profile' ? 'active' : ''}`}
            onClick={() => setActiveTab('profile')}
          >
            Profile
          </button>
          <button 
            className={`tab ${activeTab === 'security' ? 'active' : ''}`}
            onClick={() => setActiveTab('security')}
          >
            Security
          </button>
          <button 
            className={`tab ${activeTab === 'token' ? 'active' : ''}`}
            onClick={() => setActiveTab('token')}
          >
            Token Claims
          </button>
        </div>

        {activeTab === 'profile' && (
          <ProfileTab claims={claims} getRoleBadgeClass={getRoleBadgeClass} />
        )}
        {activeTab === 'security' && accessToken && (
          <SecurityTab accessToken={accessToken} />
        )}
        {activeTab === 'token' && (
          <TokenTab user={user} />
        )}
      </main>
    </div>
  )
}

function ProfileTab({ claims, getRoleBadgeClass }: { 
  claims: Record<string, any>
  getRoleBadgeClass: (role: string) => string 
}) {
  return (
    <div className="grid">
      {/* Basic Info */}
      <div className="card">
        <h3 className="card-title">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2" />
            <circle cx="12" cy="7" r="4" />
          </svg>
          Basic Information
        </h3>
        <ul className="attributes-list">
          <li className="attribute-item">
            <span className="attribute-label">Username</span>
            <span className="attribute-value">{claims.preferred_username || '-'}</span>
          </li>
          <li className="attribute-item">
            <span className="attribute-label">Full Name</span>
            <span className="attribute-value">{claims.name || '-'}</span>
          </li>
          <li className="attribute-item">
            <span className="attribute-label">Email</span>
            <span className="attribute-value">
              {claims.email || '-'}
              {claims.email_verified && <span style={{color: 'var(--success)', marginLeft: '0.25rem'}}>✓ verified</span>}
              {claims.email && !claims.email_verified && (
                <a 
                  href={getActionUrl('VERIFY_EMAIL')} 
                  style={{color: 'var(--warning)', marginLeft: '0.5rem', fontSize: '0.875rem'}}
                >
                  Verify
                </a>
              )}
            </span>
          </li>
          <li className="attribute-item">
            <span className="attribute-label">Phone</span>
            <span className="attribute-value">{claims.phone || '-'}</span>
          </li>
          <li className="attribute-item">
            <span className="attribute-label">User ID</span>
            <span className="attribute-value">{claims.sub || '-'}</span>
          </li>
        </ul>
      </div>

      {/* Roles & Groups */}
      <div className="card">
        <h3 className="card-title">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z" />
          </svg>
          Roles & Groups
        </h3>
        
        <h4 style={{ marginBottom: '0.5rem', color: 'var(--text-secondary)', fontSize: '0.875rem' }}>
          Roles
        </h4>
        <div className="roles-list" style={{ marginBottom: '1rem' }}>
          {claims.roles.length > 0 ? (
            claims.roles.map((role: string) => (
              <span key={role} className={getRoleBadgeClass(role)}>
                {role}
              </span>
            ))
          ) : (
            <span style={{ color: 'var(--text-secondary)' }}>No roles assigned</span>
          )}
        </div>

        <h4 style={{ marginBottom: '0.5rem', color: 'var(--text-secondary)', fontSize: '0.875rem' }}>
          Groups
        </h4>
        <div className="roles-list">
          {claims.groups.length > 0 ? (
            claims.groups.map((group: string) => (
              <span key={group} className="role-badge">
                {group}
              </span>
            ))
          ) : (
            <span style={{ color: 'var(--text-secondary)' }}>No groups assigned</span>
          )}
        </div>
      </div>

      {/* Custom Attributes */}
      <div className="card">
        <h3 className="card-title">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <rect x="3" y="3" width="18" height="18" rx="2" />
            <path d="M3 9h18M9 21V9" />
          </svg>
          Custom Attributes
        </h3>
        <ul className="attributes-list">
          <li className="attribute-item">
            <span className="attribute-label">Department</span>
            <span className="attribute-value">{claims.department || '-'}</span>
          </li>
          <li className="attribute-item">
            <span className="attribute-label">Employee ID</span>
            <span className="attribute-value">{claims.employee_id || '-'}</span>
          </li>
          <li className="attribute-item">
            <span className="attribute-label">Merchant ID</span>
            <span className="attribute-value">{claims.merchant_id || '-'}</span>
          </li>
        </ul>
      </div>
    </div>
  )
}

function SecurityTab({ accessToken }: { accessToken: string }) {
  const [sessions, setSessions] = useState<Session[]>([])
  const [linkedAccounts, setLinkedAccounts] = useState<LinkedAccount[]>([])
  const [credentials, setCredentials] = useState<Credential[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const headers = {
    'Authorization': `Bearer ${accessToken}`,
    'Content-Type': 'application/json'
  }

  const fetchData = useCallback(async () => {
    setLoading(true)
    setError(null)
    
    try {
      const [sessionsRes, linkedRes, credentialsRes] = await Promise.all([
        fetch(`${ACCOUNT_API}/sessions`, { headers }),
        fetch(`${ACCOUNT_API}/linked-accounts`, { headers }),
        fetch(`${ACCOUNT_API}/credentials`, { headers })
      ])

      if (sessionsRes.ok) {
        setSessions(await sessionsRes.json())
      }
      
      if (linkedRes.ok) {
        const linkedData = await linkedRes.json()
        // Handle both array and single object responses
        setLinkedAccounts(Array.isArray(linkedData) ? linkedData : [linkedData])
      }
      
      if (credentialsRes.ok) {
        const credContainers: CredentialContainer[] = await credentialsRes.json()
        // Flatten credentials from containers
        const flatCredentials: Credential[] = []
        for (const container of credContainers) {
          for (const meta of container.userCredentialMetadatas) {
            flatCredentials.push({
              id: meta.credential.id,
              type: meta.credential.type,
              userLabel: meta.credential.userLabel,
              createdDate: meta.credential.createdDate
            })
          }
        }
        setCredentials(flatCredentials)
      }
    } catch (err) {
      setError('Failed to load security data')
      console.error(err)
    } finally {
      setLoading(false)
    }
  }, [accessToken])

  useEffect(() => {
    fetchData()
  }, [fetchData])

  const deleteSession = async (sessionId: string) => {
    if (!confirm('Are you sure you want to terminate this session?')) return
    
    try {
      const res = await fetch(`${ACCOUNT_API}/sessions/${sessionId}`, {
        method: 'DELETE',
        headers
      })
      if (res.ok) {
        setSessions(prev => prev.filter(s => s.id !== sessionId))
      } else {
        alert('Failed to terminate session')
      }
    } catch (err) {
      alert('Failed to terminate session')
    }
  }

  const linkAccount = async (providerAlias: string) => {
    // Use Keycloak broker link endpoint with proper hash
    // Hash = SHA256(nonce + sessionId + clientId + provider) in Base64URL
    try {
      // Get session ID from access token
      const tokenParts = accessToken.split('.')
      const payload = JSON.parse(atob(tokenParts[1]))
      const sessionId = payload.sid || payload.session_state
      
      if (!sessionId) {
        throw new Error('Session ID not found in token')
      }
      
      const nonce = generateNonce()
      const hash = await generateBrokerLinkHash(nonce, sessionId, CLIENT_ID, providerAlias)
      const redirectUri = encodeURIComponent(window.location.origin)
      
      // Redirect to broker link endpoint
      const linkUrl = `${KEYCLOAK_BASE}/realms/${REALM}/broker/${providerAlias}/link?` +
        `client_id=${CLIENT_ID}&` +
        `redirect_uri=${redirectUri}&` +
        `nonce=${nonce}&` +
        `hash=${hash}`
      
      window.location.href = linkUrl
    } catch (err) {
      console.error('Failed to link account:', err)
      alert('Failed to initiate account linking. Please try again.')
    }
  }

  const unlinkAccount = async (providerAlias: string) => {
    if (!confirm(`Disconnect ${providerAlias}?`)) return
    try {
      const res = await fetch(`${ACCOUNT_API}/linked-accounts/${providerAlias}`, {
        method: 'DELETE',
        headers
      })
      if (res.ok) {
        fetchData()
      } else {
        alert('Failed to unlink account')
      }
    } catch (err) {
      alert('Failed to unlink account')
    }
  }

  const deleteCredential = async (credentialId: string, credentialType: string) => {
    const typeName = credentialType === 'otp' ? 'OTP' : 'Passkey'
    if (!confirm(`Delete this ${typeName}? This cannot be undone.`)) return
    try {
      const res = await fetch(`${ACCOUNT_API}/credentials/${credentialId}`, {
        method: 'DELETE',
        headers
      })
      if (res.ok) {
        setCredentials(prev => prev.filter(c => c.id !== credentialId))
      } else {
        alert(`Failed to delete ${typeName}`)
      }
    } catch (err) {
      alert(`Failed to delete ${typeName}`)
    }
  }

  if (loading) {
    return (
      <div className="card">
        <div className="loading" style={{ minHeight: '200px' }}>
          <div className="spinner"></div>
          Loading security data...
        </div>
      </div>
    )
  }

  if (error) {
    return (
      <div className="card">
        <p style={{ color: 'var(--danger)' }}>{error}</p>
        <button className="btn btn-primary" onClick={fetchData}>Retry</button>
      </div>
    )
  }

  // Categorize credentials
  const otpCredentials = credentials.filter(c => c.type === 'otp')
  const passkeys = credentials.filter(c => c.type === 'webauthn-passwordless' || c.type === 'webauthn')

  return (
    <div className="grid">
      {/* Credentials */}
      <div className="card">
        <h3 className="card-title">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <rect x="3" y="11" width="18" height="11" rx="2" ry="2" />
            <path d="M7 11V7a5 5 0 0 1 10 0v4" />
          </svg>
          Sign-in Methods
        </h3>

        {/* Password */}
        <div className="credential-section">
          <div className="credential-header">
            <h4>Password</h4>
            <span className="status status-active">Configured</span>
          </div>
          <div className="credential-actions">
            <a href={getActionUrl('UPDATE_PASSWORD')} className="btn btn-outline btn-sm">
              Change Password
            </a>
          </div>
        </div>

        {/* OTP */}
        <div className="credential-section">
          <div className="credential-header">
            <h4>Two-Factor Authentication (OTP)</h4>
            <span className={`status ${otpCredentials.length > 0 ? 'status-active' : 'status-inactive'}`}>
              {otpCredentials.length > 0 ? 'Configured' : 'Not configured'}
            </span>
          </div>
          {otpCredentials.length > 0 ? (
            <>
              <div className="credential-list">
                {otpCredentials.map(otp => (
                  <div key={otp.id} className="credential-item">
                    <span>{otp.userLabel || 'OTP Authenticator'}</span>
                    <button 
                      className="btn btn-danger btn-sm"
                      onClick={() => deleteCredential(otp.id, 'otp')}
                    >
                      Delete
                    </button>
                  </div>
                ))}
              </div>
              <div className="credential-actions">
                <a href={getActionUrl('CONFIGURE_TOTP')} className="btn btn-outline btn-sm">
                  Add Another
                </a>
              </div>
            </>
          ) : (
            <div className="credential-actions">
              <a href={getActionUrl('CONFIGURE_TOTP')} className="btn btn-outline btn-sm">
                Setup OTP
              </a>
            </div>
          )}
        </div>

        {/* Passkeys */}
        <div className="credential-section">
          <div className="credential-header">
            <h4>Passkeys</h4>
            <span className={`status ${passkeys.length > 0 ? 'status-active' : 'status-inactive'}`}>
              {passkeys.length > 0 ? `${passkeys.length} configured` : 'Not configured'}
            </span>
          </div>
          {passkeys.length > 0 && (
            <div className="credential-list">
              {passkeys.map(pk => (
                <div key={pk.id} className="credential-item">
                  <div>
                    <span>{pk.userLabel || 'Passkey'}</span>
                    {pk.createdDate && (
                      <small style={{ display: 'block', color: 'var(--text-secondary)' }}>
                        Added {new Date(pk.createdDate).toLocaleDateString()}
                      </small>
                    )}
                  </div>
                  <button 
                    className="btn btn-danger btn-sm"
                    onClick={() => deleteCredential(pk.id, pk.type)}
                  >
                    Delete
                  </button>
                </div>
              ))}
            </div>
          )}
          <div className="credential-actions" style={{ marginTop: passkeys.length > 0 ? '0.5rem' : 0 }}>
            <a href={getActionUrl('webauthn-register-passwordless')} className="btn btn-outline btn-sm">
              {passkeys.length > 0 ? 'Add Another Passkey' : 'Setup Passkey'}
            </a>
          </div>
        </div>
      </div>

      {/* Linked Accounts */}
      <div className="card">
        <h3 className="card-title">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71" />
            <path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71" />
          </svg>
          Linked Accounts
        </h3>
        
        {linkedAccounts.length === 0 ? (
          <p style={{ color: 'var(--text-secondary)' }}>No identity providers available</p>
        ) : (
          <div className="linked-accounts-list">
            {linkedAccounts.map(account => (
              <div key={account.providerAlias} className="linked-account-item">
                <div className="provider-info">
                  <div className="provider-icon">
                    {account.providerAlias === 'google' && (
                      <svg viewBox="0 0 24 24" width="24" height="24">
                        <path fill="#4285F4" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"/>
                        <path fill="#34A853" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"/>
                        <path fill="#FBBC05" d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"/>
                        <path fill="#EA4335" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"/>
                      </svg>
                    )}
                    {account.providerAlias !== 'google' && (
                      <span style={{ fontSize: '1.5rem' }}>🔗</span>
                    )}
                  </div>
                  <div>
                    <div className="provider-name">{account.providerName || account.providerAlias}</div>
                    {account.connected && account.linkedUsername && (
                      <div className="provider-username">{account.linkedUsername}</div>
                    )}
                  </div>
                </div>
                <div className="provider-actions">
                  {account.connected ? (
                    <button 
                      className="btn btn-danger btn-sm"
                      onClick={() => unlinkAccount(account.providerAlias)}
                    >
                      Disconnect
                    </button>
                  ) : (
                    <button 
                      className="btn btn-primary btn-sm"
                      onClick={() => linkAccount(account.providerAlias)}
                    >
                      Connect
                    </button>
                  )}
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Active Sessions */}
      <div className="card">
        <h3 className="card-title">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <rect x="2" y="3" width="20" height="14" rx="2" ry="2" />
            <line x1="8" y1="21" x2="16" y2="21" />
            <line x1="12" y1="17" x2="12" y2="21" />
          </svg>
          Active Sessions
        </h3>
        
        {sessions.length === 0 ? (
          <p style={{ color: 'var(--text-secondary)' }}>No active sessions</p>
        ) : (
          <div className="sessions-list">
            {sessions.map(session => (
              <div key={session.id} className="session-item">
                <div className="session-info">
                  <div className="session-browser">
                    {session.browser || 'Unknown Browser'}
                    {session.current && <span className="current-badge">Current</span>}
                  </div>
                  <div className="session-details">
                    <span>IP: {session.ipAddress}</span>
                    <span>Started: {new Date(session.started * 1000).toLocaleString()}</span>
                    <span>Last access: {new Date(session.lastAccess * 1000).toLocaleString()}</span>
                  </div>
                  {session.clients && session.clients.length > 0 && (
                    <div className="session-clients">
                      Apps: {session.clients.map(c => c.clientName || c.clientId).join(', ')}
                    </div>
                  )}
                </div>
                {!session.current && (
                  <button 
                    className="btn btn-danger btn-sm"
                    onClick={() => deleteSession(session.id)}
                  >
                    Terminate
                  </button>
                )}
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  )
}

function TokenTab({ user }: { user: any }) {
  const [showSection, setShowSection] = useState<'id' | 'access' | 'profile'>('profile')

  const getTokenData = () => {
    switch (showSection) {
      case 'id':
        return user?.id_token ? parseJwt(user.id_token) : null
      case 'access':
        return user?.access_token ? parseJwt(user.access_token) : null
      case 'profile':
        return user?.profile
      default:
        return null
    }
  }

  return (
    <div className="card">
      <h3 className="card-title">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
          <polyline points="16 18 22 12 16 6" />
          <polyline points="8 6 2 12 8 18" />
        </svg>
        Token Claims
      </h3>
      
      <div style={{ marginBottom: '1rem' }}>
        <button 
          className={`btn ${showSection === 'profile' ? 'btn-primary' : 'btn-secondary'}`}
          onClick={() => setShowSection('profile')}
          style={{ marginRight: '0.5rem' }}
        >
          User Profile
        </button>
        <button 
          className={`btn ${showSection === 'id' ? 'btn-primary' : 'btn-secondary'}`}
          onClick={() => setShowSection('id')}
          style={{ marginRight: '0.5rem' }}
        >
          ID Token
        </button>
        <button 
          className={`btn ${showSection === 'access' ? 'btn-primary' : 'btn-secondary'}`}
          onClick={() => setShowSection('access')}
        >
          Access Token
        </button>
      </div>

      <pre className="token-viewer">
        {JSON.stringify(getTokenData(), null, 2)}
      </pre>
    </div>
  )
}

// Parse JWT token
function parseJwt(token: string) {
  try {
    const base64Url = token.split('.')[1]
    const base64 = base64Url.replace(/-/g, '+').replace(/_/g, '/')
    const jsonPayload = decodeURIComponent(
      atob(base64)
        .split('')
        .map(c => '%' + ('00' + c.charCodeAt(0).toString(16)).slice(-2))
        .join('')
    )
    return JSON.parse(jsonPayload)
  } catch {
    return null
  }
}

export default App
