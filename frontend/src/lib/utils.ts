import { type ClassValue, clsx } from "clsx"
import { twMerge } from "tailwind-merge"

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}

export function formatEther(value: bigint, decimals: number = 18): string {
  const divisor = BigInt(10 ** decimals)
  const quotient = value / divisor
  const remainder = value % divisor
  
  if (remainder === 0n) {
    return quotient.toString()
  }
  
  const remainderStr = remainder.toString().padStart(decimals, '0')
  const trimmedRemainder = remainderStr.replace(/0+$/, '')
  
  return `${quotient}.${trimmedRemainder}`
}

export function parseEther(value: string, decimals: number = 18): bigint {
  const [integer, decimal = ''] = value.split('.')
  const paddedDecimal = decimal.padEnd(decimals, '0').slice(0, decimals)
  return BigInt(integer + paddedDecimal)
}

export function shortenAddress(address: string): string {
  return `${address.slice(0, 6)}...${address.slice(-4)}`
}