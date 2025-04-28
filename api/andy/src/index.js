
import Fastify from 'fastify';
import dotenv from 'dotenv';

import {sendMessages} from './producer.js';


dotenv.config();
const app = Fastify({
    disableRequestLogging: true,
    prettyPrint: false,
    logger: {
        transport: {
            target: 'pino-pretty',
            options: {
                translateTime: 'yyyy-mm-dd HH:MM:ss Z',
                ignore: 'pid,hostname',
            },
        },
    },
})


app.post('/temperature', async (request, reply) => {
    await sendMessages(request.body);
    app.log.info("Completed sending message to Kafka");
    reply.send({ status: 'OK' });
  });

app.get('/health-check', async (request, reply) => {
    return { ping: 'OK' }
})
app.get('/', function (request, reply) {
    reply.send("Andy's API.")
})

/**
 * Run the server!
 */
const start = async () => {
    try {
        await app.listen(
            { port: process.env.PORT, host: '0.0.0.0' }
        )
    } catch (err) {
        fastify.log.error(err)
        process.exit(1)
    }
}
start()