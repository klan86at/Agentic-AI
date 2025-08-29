import { useAuth } from '@/contexts/AuthContext';
import JacChatbot from '@/components/JacChatbot';
import AdminDashboard from '@/components/AdminDashboard';

const Dashboard = () => {
  const { isAdmin } = useAuth();

  // Show admin dashboard for admin email, regular chat for others
  if (isAdmin) {
    return <AdminDashboard />;
  }

  return <JacChatbot />;
};

export default Dashboard;
