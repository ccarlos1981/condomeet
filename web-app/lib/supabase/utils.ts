
/**
 * Fetches all rows from a Supabase query by paginating through the results.
 * This bypasses the PostgREST `max_rows` API limit (default 1000).
 */
export async function fetchAll<T = unknown>(
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  query: any, // The Supabase query builder (e.g., supabase.from('table').select('*').eq('x', 'y'))
  chunkSize: number = 1000
): Promise<T[]> {
  const allData: T[] = []
  let from = 0
  let to = chunkSize - 1
  let hasMore = true

  while (hasMore) {
    // Supabase .range() is inclusive at both ends
    const { data, error } = await query.range(from, to)

    if (error) {
      throw error
    }

    if (data && data.length > 0) {
      allData.push(...data)
      if (data.length < chunkSize) {
        hasMore = false // Fetched fewer than chunkSize, meaning this was the last page
      } else {
        from += chunkSize
        to += chunkSize
      }
    } else {
      hasMore = false // No more data
    }
  }

  return allData
}
