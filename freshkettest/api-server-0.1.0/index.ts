import { z } from 'zod'
import { OpenAPIHono } from '@hono/zod-openapi'
import { createRoute } from '@hono/zod-openapi'
import { swaggerUI } from '@hono/swagger-ui'
import { serve } from 'bun'
import { faker } from '@faker-js/faker'

const productSchema = z.object({
  id: z.number(),
  name: z.string(),
  price: z.number(),
})

type Product = z.infer<typeof productSchema>

const generateProduct = (id: number): Product => {
  return {
    id,
    name: faker.commerce.product(),
    price: Number(faker.commerce.price({ min: 19, max: 1290, dec: 2 })),
  }
}

const app = new OpenAPIHono()

app.openapi(
  createRoute({
    method: 'get',
    path: '/healthcheck',
    request: {},
    responses: {
      200: {
        content: {
          'text/plain': {
            schema: z.literal('OK'),
          },
        },
        description: '',
      },
    },
  }),
  (c) => {
    return c.text('OK', 200)
  },
)

app.openapi(
  createRoute({
    method: 'get',
    path: '/products',
    request: {
      query: z.object({
        cursor: z.string().max(200).optional(),
        limit: z.preprocess((val) => Number(val) || 20, z.number().max(100).default(20)),
      }),
    },
    responses: {
      200: {
        content: {
          'application/json': {
            schema: z.object({
              items: z.array(productSchema),
              nextCursor: z.string().nullable(),
            }),
          },
        },
        description: '',
      },
    },
  }),
  async (c) => {
    const { cursor, limit } = c.req.valid('query')

    const rn = Math.random()

    if (rn >= 0.1) await new Promise((r) => setTimeout(r, 1000 * rn))

    const products: Product[] = []

    const start = !!cursor ? Number(Buffer.from(cursor, 'base64').toString()) : 1

    for (let i = 0; i < limit; i++) {
      const id = start + i

      if (id > 658) break

      products.push(generateProduct(id))
    }

    return c.json(
      {
        items: products,
        nextCursor: products.length > 0 ? Buffer.from(products[products.length - 1].id.toString()).toString('base64') : null,
      },
      200,
    )
  },
)

app.openapi(
  createRoute({
    method: 'get',
    path: '/recommended-products',
    request: {},
    responses: {
      200: {
        content: {
          'application/json': {
            schema: z.array(productSchema),
          },
        },
        description: '',
      },
      500: {
        content: {
          'application/json': {
            schema: z.object({ message: z.string() }),
          },
        },
        description: '',
      },
      502: {
        content: {
          'text/plain': {
            schema: z.string(),
          },
        },
        description: '',
      },
    },
  }),
  async (c) => {
    const rn = Math.random()

    if (rn >= 0.9) return c.text('502 Bad Gateway', 502)

    if (rn >= 0.1 && rn <= 0.2) return c.json({ message: 'Internal Server Error' }, 500)

    await new Promise((r) => setTimeout(r, 1000 * rn))

    const products: Product[] = []

    for (let i = 0; i < 23; i++) {
      const id = i + 1

      products.push(generateProduct(id))
    }

    return c.json(products, 200)
  },
)

app.openapi(
  createRoute({
    method: 'post',
    path: '/orders/checkout',
    request: {
      body: {
        content: {
          'application/json': {
            schema: z.object({
              products: z.array(z.number().min(0)).min(1).max(1000),
            }),
          },
        },
      },
    },
    responses: {
      204: {
        description: '',
      },
      500: {
        content: {
          'application/json': {
            schema: z.object({ message: z.string() }),
          },
        },
        description: '',
      },
      502: {
        content: {
          'text/plain': {
            schema: z.string(),
          },
        },
        description: '',
      },
    },
  }),
  async (c) => {
    const rn = Math.random()

    if (rn >= 0.9) return c.text('502 Bad Gateway', 502)

    if (rn >= 0.1 && rn <= 0.2) return c.json({ message: 'Internal Server Error' }, 500)

    await new Promise((r) => setTimeout(r, 1000 * rn))

    return c.text('', 204)
  },
)

app.doc('/openapi', {
  openapi: '3.0.0',
  info: {
    version: '1.0.0',
    title: '',
  },
})

app.get('/swagger', swaggerUI({ url: '/openapi' }))

serve({
  fetch: app.fetch,
  port: 8080,
})
