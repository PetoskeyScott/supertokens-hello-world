import React, { useEffect, useState } from 'react';
import { signOut } from "supertokens-auth-react/recipe/emailpassword";
import Session from "supertokens-auth-react/recipe/session";

interface User {
    userId: string;
    role: string;
}

const Home: React.FC = () => {
    const [users, setUsers] = useState<User[]>([]);
    const [accountId, setAccountId] = useState<string | null>(null);

    useEffect(() => {
        const fetchUsers = async () => {
            try {
                const session = await Session.getAccessTokenPayloadSecurely();
                if (session.accountId) {
                    setAccountId(session.accountId);
                    const response = await fetch(`/api/account/${session.accountId}/users`);
                    const data = await response.json();
                    setUsers(data);
                }
            } catch (err) {
                console.error('Error fetching users:', err);
            }
        };

        fetchUsers();
    }, []);

    const handleSignOut = async () => {
        await signOut();
        window.location.href = '/auth';
    };

    return (
        <div style={{ padding: '20px' }}>
            <h1>Hello World!</h1>
            <p>Welcome to your account dashboard</p>
            
            {accountId && (
                <div>
                    <h2>Account ID: {accountId}</h2>
                    <h3>Users in this account:</h3>
                    <ul>
                        {users.map((user, index) => (
                            <li key={index}>
                                User ID: {user.userId} - Role: {user.role}
                            </li>
                        ))}
                    </ul>
                </div>
            )}

            <button 
                onClick={handleSignOut}
                style={{
                    padding: '10px 20px',
                    marginTop: '20px',
                    backgroundColor: '#ff4444',
                    color: 'white',
                    border: 'none',
                    borderRadius: '4px',
                    cursor: 'pointer'
                }}
            >
                Sign Out
            </button>
        </div>
    );
};

export default Home; 