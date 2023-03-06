import {S3Client, CopyObjectCommand, DeleteObjectCommand, HeadObjectCommand} from "@aws-sdk/client-s3";
import { DynamoDBClient, PutItemCommand, GetItemCommand } from "@aws-sdk/client-dynamodb";
import { unmarshall } from "@aws-sdk/util-dynamodb";

export const handler = async ({key, userid}) => {
	const {Bucket, ImageTable} = process.env;
	const s3Client = new S3Client();
	const ddbClient = new DynamoDBClient();
	const obj = await s3Client.send(new HeadObjectCommand({
		Bucket,
		Key: `staging/${key}`,
	}));
	if (obj.Metadata.userid !== userid) {
		console.error(`User is different than the uploading user. User: ${userid}, uploading user: ${obj.Metadata.userid}`);
		throw new Error("");
	}
	await s3Client.send(new CopyObjectCommand({
		Bucket,
		Key: key,
		CopySource: encodeURI(`${Bucket}/staging/${key}`),
	}));
	const [, result] = await Promise.all([
		s3Client.send(new DeleteObjectCommand({
			Bucket,
			Key: `staging/${key}`,
		})),
		(async () => {
			const isPublic = false;

			await ddbClient.send(new PutItemCommand({
				TableName: ImageTable,
				Item: {
					key: {S: key},
					userid: {S: userid},
					public: {BOOL: isPublic},
					"userid#public": {S: userid + "#" + isPublic},
					added: {N: new Date().getTime().toString()},
				}
			}));
			const res = await ddbClient.send(new GetItemCommand({
				TableName: ImageTable,
				Key: {
					key: {S: key},
				},
			}));
			return unmarshall(res.Item);
		})(),
	]);
	return result;
};

