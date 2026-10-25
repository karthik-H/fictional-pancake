export type User = {
  id: string;
  email: string;
  name: string;
  passwordHash: string;
};

export type PublicUser = {
  id: string;
  email: string;
  name: string;
};

export type Product = {
  id: string;
  name: string;
  description: string;
  priceCents: number;
  sku: string;
  createdAt: string;
};

export type TokenPayload = {
  sub: string;
  email: string;
  exp: number;
};
