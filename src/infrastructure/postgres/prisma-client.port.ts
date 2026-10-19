export interface PrismaQueryClient {
  $queryRaw<T = unknown>(query: TemplateStringsArray, ...values: unknown[]): Promise<T>;
}

export interface PrismaDatabaseClient extends PrismaQueryClient {
  $transaction<T>(operation: (client: PrismaQueryClient) => Promise<T>): Promise<T>;
}
