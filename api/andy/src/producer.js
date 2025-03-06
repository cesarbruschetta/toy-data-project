import pino from 'pino';
import { v4 as uuid_v4 } from "uuid";
import { Kafka, Partitioners } from 'kafkajs';

const log = pino({ level: 'info' })
const kafka = new Kafka({
    clientId: 'andy-api',
    brokers: [
        process.env.KAFKA_BROKER
    ]
});
const producer = kafka.producer(
    { createPartitioner: Partitioners.DefaultPartitioner }
);

const sendMessages = async (messages) => {
    log.info(`Sending messages to topic: ${process.env.KAFKA_TOPIC}`);
    await producer.connect();
    await producer.send({
        topic: process.env.KAFKA_TOPIC,
        messages: [
            { 
                key: uuid_v4(), 
                value: JSON.stringify(
                    { ...messages, timestamp: Date.now() }
                ) 
            }
        ]
    });
}

export {
    sendMessages
};