import { Environment } from '@repo/db-common/enums'
import { useMemo } from 'react'

type LogoConfig = {
  src: string
  alt: string
  width: number
  height: number
}

const logosPerEnvironment: Record<string, LogoConfig[]> = {
  [Environment.CUT]: [{ src: '/logos/cut/logo.svg', alt: 'Logo de COUNT', width: 98, height: 48 }],
  [Environment.TILT]: [
    { src: '/logos/abc/logo_abc_base.png', alt: 'Logo ABC', width: 84, height: 28 },
    { src: '/logos/tilt/logo_tilt.svg', alt: 'Logo TILT', width: 82, height: 28 },
  ],
  [Environment.CLICKSON]: [{ src: '/logos/clickson/logo_clickson.png', alt: 'Logo Clickson', width: 65, height: 35 }],
  DEFAULT: [
    {
      // SolutionsPlus rebrand (2026-05-21). Logo source quasi carré (1831x1440, ratio ~1.27).
      // Anciennement /logos/logo_bc_blanc_nospace.png (1028x368, ratio ~2.79) — fichier conservé pour rollback.
      src: '/logos/logo_solutionsplus.png',
      alt: 'Logo SolutionsPlus',
      width: 45,
      height: 35,
    },
  ],
}

interface Props {
  environment?: Environment
}

export const Logo = ({ environment }: Props) => {
  const logos = useMemo(
    () => (environment && logosPerEnvironment[environment]) ?? logosPerEnvironment.DEFAULT,
    [environment],
  )

  return (
    <div className="h100 align-center gapped1">
      {logos.map(({ src, alt, width, height }) => (
        // With dynamic images size next/Image generates a CSP error
        // eslint-disable-next-line @next/next/no-img-element
        <img key={src} data-testid={`logo-${environment}`} src={src} alt={alt} width={width} height={height} />
      ))}
    </div>
  )
}
