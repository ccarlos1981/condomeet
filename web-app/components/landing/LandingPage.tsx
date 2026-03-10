import LandingNav from './LandingNav'
import HeroSection from './HeroSection'
import StatsBar from './StatsBar'
import FeaturesSection from './FeaturesSection'
import HowItWorks from './HowItWorks'
import TrialCTA from './TrialCTA'
import TestimonialsSection from './TestimonialsSection'
import AppDownloadSection from './AppDownloadSection'
import LandingFooter from './LandingFooter'

export default function LandingPage() {
  return (
    <div className="lp-root">
      <LandingNav />
      <main>
        <HeroSection />
        <StatsBar />
        <FeaturesSection />
        <HowItWorks />
        <TrialCTA />
        <TestimonialsSection />
        <AppDownloadSection />
      </main>
      <LandingFooter />
    </div>
  )
}
