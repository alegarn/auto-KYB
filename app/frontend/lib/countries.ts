export interface Country {
  name: string;
  code: string;
  flag: string;
  is_automated?: boolean;
}

function getFlagEmoji(countryCode: string) {
  if (!countryCode) return '';
  const codePoints = countryCode
    .toUpperCase()
    .split('')
    .map((char) => 127397 + char.charCodeAt(0));
  return String.fromCodePoint(...codePoints);
}

export async function fetchCountriesData(): Promise<Country[]> {
  // Prevent browser caching of old boolean-corrupted data
  const res = await fetch('/countries?v=3'); 
  if (!res.ok) {
    throw new Error(`HTTP ${res.status} - ${res.statusText}`);
  }
  const data = await res.json();
  
  return data
    .map((c: any) => ({
      ...c,
      flag: getFlagEmoji(c.code)
    }))
    .sort((a: Country, b: Country) => a.name.localeCompare(b.name));
}

