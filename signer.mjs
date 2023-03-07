import {S3Client, GetObjectCommand} from "@aws-sdk/client-s3";
import {getSignedUrl} from "@aws-sdk/s3-request-presigner";
import {createPresignedPost} from "@aws-sdk/s3-presigned-post";
import crypto from "node:crypto";

export const handler = async (event) => {
	const client = new S3Client();
	return Promise.all(event.map(async ({type, imageKey, userid}) => {
		if (type === "download") {
			const roundTo = 5 * 60 * 1000; // 5 minutes
			const signedUrl = await getSignedUrl(client, new GetObjectCommand({
				Bucket: process.env.Bucket,
				Key: imageKey,
			}), {signingDate: new Date(Math.floor(new Date().getTime() / roundTo) * roundTo)});
			return {
				data: signedUrl,
			};
		}else if (type === "upload") {
			const key = crypto.randomUUID();
			const data = await createPresignedPost(client, {
				Bucket: process.env.Bucket,
				Key: "staging/" + key,
				Fields: {
					"x-amz-meta-userid": userid,
					"x-amz-meta-key": key,
				},
				Conditions: [
					["content-length-range", 	0, 10000000], // content length restrictions: 0-10MB
					["starts-with", "$Content-Type", "image/"], // content type restriction
					["eq", "$x-amz-meta-userid", userid], // tag with userid <= the user can see this!
					["eq", "$x-amz-meta-key", key],
				]
			});
			return {data};
		}else {
			return {errorMessage: "Unknown type", errorType: "Custom"};
		}
	}));
};
