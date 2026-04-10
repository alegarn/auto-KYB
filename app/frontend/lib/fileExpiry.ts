type ComputeOpts = { policyRetentionDays?: number };

function tryParseIso(iso?: string | null): Date | null {
  if (!iso) return null;
  const d = new Date(iso);
  return isNaN(d.getTime()) ? null : d;
}

function secondsBetween(a: Date, b: Date) {
  return Math.round((a.getTime() - b.getTime()) / 1000);
}

export function parseExpiryFromSignedUrl(url?: string | null): Date | null {
  if (!url) return null;
  try {
    const u = new URL(url);
    const p = u.searchParams;
    // Common query names: Expires, exp, X-Amz-Expires + X-Amz-Date
    if (p.has('Expires')) {
      const v = p.get('Expires');
      const t = Number(v);
      if (!isNaN(t)) return new Date(t * 1000);
    }
    if (p.has('exp')) {
      const v = p.get('exp');
      const t = Number(v);
      if (!isNaN(t)) return new Date(t * 1000);
    }
    if (p.has('X-Amz-Expires')) {
      // Need X-Amz-Date as well: format YYYYMMDD'T'HHMMSS'Z'
      const expiresSec = Number(p.get('X-Amz-Expires'));
      const amzDate = p.get('X-Amz-Date');
      if (!isNaN(expiresSec) && amzDate) {
        // Try parse X-Amz-Date
        const year = Number(amzDate.slice(0, 4));
        const month = Number(amzDate.slice(4, 6)) - 1;
        const day = Number(amzDate.slice(6, 8));
        const hour = Number(amzDate.slice(9, 11));
        const minute = Number(amzDate.slice(11, 13));
        const second = Number(amzDate.slice(13, 15));
        const base = new Date(Date.UTC(year, month, day, hour, minute, second));
        if (!isNaN(base.getTime())) return new Date(base.getTime() + expiresSec * 1000);
      }
    }
  } catch {
    return null;
  }
  return null;
}

export function formatDuration(seconds?: number | null): string | null {
  if (seconds == null) return null;
  if (seconds <= 0) return 'expired';
  if (seconds < 60) return `${seconds}s`;
  if (seconds < 3600) return `${Math.floor(seconds / 60)}m ${seconds % 60}s`;
  if (seconds < 86400) return `${Math.floor(seconds / 3600)}h ${Math.floor((seconds % 3600) / 60)}m`;
  return `${Math.floor(seconds / 86400)}d ${Math.floor((seconds % 86400) / 3600)}h`;
}

export function computeFileExpiry(file: any, opts: ComputeOpts = {}) {
  const now = new Date();
  const out: {
    expiresAtIso?: string | null;
    expiresAt?: Date | null;
    remainingSeconds?: number | null;
    policyUsed?: number | null;
    source?: 'expires_at' | 'signed_url' | 'expires_in_seconds' | 'policy' | 'none';
  } = { policyUsed: null } as any;

  // 1) explicit expires_at
  if (file?.expires_at) {
    const d = tryParseIso(file.expires_at);
    if (d) {
      out.expiresAt = d;
      out.expiresAtIso = d.toISOString();
      out.remainingSeconds = secondsBetween(d, now);
      out.source = 'expires_at';
      return out;
    }
  }

  // 2) parse signed URL
  const signedCandidates = file?.signed_url || file?.download_url || file?.url || null;
  if (signedCandidates) {
    const d = parseExpiryFromSignedUrl(signedCandidates);
    if (d) {
      out.expiresAt = d;
      out.expiresAtIso = d.toISOString();
      out.remainingSeconds = secondsBetween(d, now);
      out.source = 'signed_url';
      return out;
    }
  }

  // 3) expires_in_seconds relative to uploaded_at
  if (file?.expires_in_seconds != null && file?.uploaded_at) {
    const uploaded = tryParseIso(file.uploaded_at);
    const ttl = Number(file.expires_in_seconds);
    if (uploaded && !isNaN(ttl)) {
      const d = new Date(uploaded.getTime() + ttl * 1000);
      out.expiresAt = d;
      out.expiresAtIso = d.toISOString();
      out.remainingSeconds = secondsBetween(d, now);
      out.source = 'expires_in_seconds';
      return out;
    }
  }

  // 4) fallback to server retention policy if provided
  if (opts.policyRetentionDays && file?.uploaded_at) {
    const uploaded = tryParseIso(file.uploaded_at);
    const days = Number(opts.policyRetentionDays);
    if (uploaded && !isNaN(days)) {
      const d = new Date(uploaded.getTime() + days * 24 * 3600 * 1000);
      out.expiresAt = d;
      out.expiresAtIso = d.toISOString();
      out.remainingSeconds = secondsBetween(d, now);
      out.policyUsed = days;
      out.source = 'policy';
      return out;
    }
  }

  out.source = 'none';
  out.expiresAt = null;
  out.expiresAtIso = null;
  out.remainingSeconds = null;
  return out;
}

export default {
  computeFileExpiry,
  parseExpiryFromSignedUrl,
  formatDuration,
};
