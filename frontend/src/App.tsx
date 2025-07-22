import React from 'react'
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom'
import { Toaster } from './components/ui/toaster'
import { ThemeProvider } from './contexts/ThemeContext'
import Navigation from './components/Navigation'
import TokenBankPage from './pages/TokenBankPage'
import NFTMarketPage from './pages/NFTMarketPage'

function App() {
  return (
    <ThemeProvider>
      <Router>
        <div className="min-h-screen bg-background transition-colors duration-300">
          <Navigation />
        
        <main className="container mx-auto px-4 py-8">
          <Routes>
            <Route path="/" element={<Navigate to="/tokenbank" replace />} />
            <Route path="/tokenbank" element={<TokenBankPage />} />
            <Route path="/nft-market" element={<NFTMarketPage />} />
          </Routes>
        </main>

        {/* Footer */}
        <footer className="border-t mt-16">
          <div className="container mx-auto px-4 py-6">
            <div className="text-center text-sm text-muted-foreground">
              <p>TokenBank DApp - 基于 React + Viem + shadcn/ui 构建</p>
            </div>
          </div>
        </footer>

        <Toaster />
        </div>
      </Router>
    </ThemeProvider>
  )
}

export default App