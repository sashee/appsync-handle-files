resource "aws_appsync_resolver" "Query_allUsers" {
  api_id = aws_appsync_graphql_api.appsync.id
  type   = "Query"
  field  = "allUsers"
  runtime {
    name            = "APPSYNC_JS"
    runtime_version = "1.0.0"
  }
  code = <<EOF
export function request(ctx) {
	return {};
}
export function response(ctx) {
	return ctx.result;
}
EOF
  kind = "PIPELINE"
  pipeline_config {
    functions = [
      aws_appsync_function.Query_allUsers_1.function_id,
    ]
  }
}
resource "aws_appsync_function" "Query_allUsers_1" {
  api_id      = aws_appsync_graphql_api.appsync.id
  data_source = aws_appsync_datasource.ddb_users.name
  name        = "Query_allUsers_1"
  runtime {
    name            = "APPSYNC_JS"
    runtime_version = "1.0.0"
  }
  code = <<EOF
import {util} from "@aws-appsync/utils";
export function request(ctx) {
	return {
		version : "2018-05-29",
		operation : "Scan",
		nextToken: ctx.args.nextToken,
	};
}
export function response(ctx) {
	if (ctx.error) {
		return util.error(ctx.error.message, ctx.error.type);
	}
	return {
		users: ctx.result.items,
		nextToken: ctx.result.nextToken,
	};
}
EOF
}
resource "aws_appsync_resolver" "User_images" {
  api_id = aws_appsync_graphql_api.appsync.id
  type   = "User"
  field  = "images"
  runtime {
    name            = "APPSYNC_JS"
    runtime_version = "1.0.0"
  }
  code = <<EOF
export function request(ctx) {
	return {};
}
export function response(ctx) {
	return ctx.result;
}
EOF
  kind = "PIPELINE"
  pipeline_config {
    functions = [
      aws_appsync_function.User_images_1.function_id,
    ]
  }
}
resource "aws_appsync_function" "User_images_1" {
  api_id      = aws_appsync_graphql_api.appsync.id
  data_source = aws_appsync_datasource.ddb_images.name
  name        = "User_images_1"
  runtime {
    name            = "APPSYNC_JS"
    runtime_version = "1.0.0"
  }
  code = <<EOF
import {util} from "@aws-appsync/utils";
export function request(ctx) {
	return {
		version : "2018-05-29",
		operation : "Query",
		...(ctx.source.id === ctx.identity.sub ? {
			index: "userid",
			query: {
				expression: "#userid = :userid",
				expressionNames: {
					"#userid": "userid",
				},
				expressionValues: {
					":userid": {S: ctx.source.id},
				},
			},
		} : {
			index: "useridPublic",
			query: {
				expression: "#useridPublic = :useridPublic",
				expressionNames: {
					"#useridPublic": "userid#public",
				},
				expressionValues: {
					":useridPublic": {S: ctx.source.id + "#true"},
				},
			},
		}),
		nextToken: ctx.args.nextToken,
		scanIndexForward: false,
	};
}
export function response(ctx) {
	if (ctx.error) {
		return util.error(ctx.error.message, ctx.error.type);
	}
	return {
		images: ctx.result.items,
		nextToken: ctx.result.nextToken,
	};
}
EOF
}
resource "aws_appsync_resolver" "Image_url" {
  api_id = aws_appsync_graphql_api.appsync.id
  type   = "Image"
  field  = "url"
  runtime {
    name            = "APPSYNC_JS"
    runtime_version = "1.0.0"
  }
  code = <<EOF
export function request(ctx) {
	return {};
}
export function response(ctx) {
	return ctx.result;
}
EOF
  kind = "PIPELINE"
  pipeline_config {
    functions = [
      aws_appsync_function.Image_url_1.function_id,
    ]
  }
}
resource "aws_appsync_function" "Image_url_1" {
  api_id      = aws_appsync_graphql_api.appsync.id
  data_source = aws_appsync_datasource.lambda_signer.name
  name        = "Image_url_1"
  runtime {
    name            = "APPSYNC_JS"
    runtime_version = "1.0.0"
  }
  code = <<EOF
import {util} from "@aws-appsync/utils";
export function request(ctx) {
	return {
		version: "2018-05-29",
		operation: "BatchInvoke",
		payload: {
			type: "download",
			imageKey: ctx.source.key,
		}
	};
}
export function response(ctx) {
	if (ctx.error) {
		return util.error(ctx.error.message, ctx.error.type);
	}
	if (ctx.result.errorMessage) {
		return util.error(ctx.result.errorMessage, ctx.result.errorType);
	}
	return ctx.result.data;
}
EOF
}
resource "aws_appsync_resolver" "Query_getUploadURL" {
  api_id = aws_appsync_graphql_api.appsync.id
  type   = "Query"
  field  = "getUploadURL"
  runtime {
    name            = "APPSYNC_JS"
    runtime_version = "1.0.0"
  }
  code = <<EOF
export function request(ctx) {
	return {};
}
export function response(ctx) {
	return ctx.result;
}
EOF
  kind = "PIPELINE"
  pipeline_config {
    functions = [
      aws_appsync_function.Query_getUploadURL_1.function_id,
    ]
  }
}
resource "aws_appsync_function" "Query_getUploadURL_1" {
  api_id      = aws_appsync_graphql_api.appsync.id
  data_source = aws_appsync_datasource.lambda_signer.name
  name        = "Query_getUploadURL_1"
  runtime {
    name            = "APPSYNC_JS"
    runtime_version = "1.0.0"
  }
  code = <<EOF
import {util} from "@aws-appsync/utils";
export function request(ctx) {
	return {
		version: "2018-05-29",
		operation: "BatchInvoke",
		payload: {
			type: "upload",
			userid: ctx.identity.sub,
		}
	};
}
export function response(ctx) {
	if (ctx.error) {
		return util.error(ctx.error.message, ctx.error.type);
	}
	if (ctx.result.errorMessage) {
		return util.error(ctx.result.errorMessage, ctx.result.errorType);
	}
	return ctx.result.data;
}
EOF
}
resource "aws_appsync_resolver" "Query_currentUser" {
  api_id = aws_appsync_graphql_api.appsync.id
  type   = "Query"
  field  = "currentUser"
  runtime {
    name            = "APPSYNC_JS"
    runtime_version = "1.0.0"
  }
  code = <<EOF
export function request(ctx) {
	return {};
}
export function response(ctx) {
	return ctx.result;
}
EOF
  kind = "PIPELINE"
  pipeline_config {
    functions = [
      aws_appsync_function.Query_currentUser_1.function_id,
    ]
  }
}
resource "aws_appsync_function" "Query_currentUser_1" {
  api_id      = aws_appsync_graphql_api.appsync.id
  data_source = aws_appsync_datasource.ddb_users.name
  name        = "Query_currentUser_1"
  runtime {
    name            = "APPSYNC_JS"
    runtime_version = "1.0.0"
  }
  code = <<EOF
import {util} from "@aws-appsync/utils";
export function request(ctx) {
	return {
		version : "2018-05-29",
		operation : "GetItem",
		key: {
			id: {S: ctx.identity.sub}
		}
	};
}
export function response(ctx) {
	if (ctx.error) {
		return util.error(ctx.error.message, ctx.error.type);
	}
	return ctx.result;
}
EOF
}
resource "aws_appsync_resolver" "Query_user" {
  api_id = aws_appsync_graphql_api.appsync.id
  type   = "Query"
  field  = "user"
  runtime {
    name            = "APPSYNC_JS"
    runtime_version = "1.0.0"
  }
  code = <<EOF
export function request(ctx) {
	return {};
}
export function response(ctx) {
	return ctx.result;
}
EOF
  kind = "PIPELINE"
  pipeline_config {
    functions = [
      aws_appsync_function.Query_user_1.function_id,
    ]
  }
}
resource "aws_appsync_function" "Query_user_1" {
  api_id      = aws_appsync_graphql_api.appsync.id
  data_source = aws_appsync_datasource.ddb_users.name
  name        = "Query_user_1"
  runtime {
    name            = "APPSYNC_JS"
    runtime_version = "1.0.0"
  }
  code = <<EOF
import {util} from "@aws-appsync/utils";
export function request(ctx) {
	return {
		version : "2018-05-29",
		operation : "GetItem",
		key: {
			id: {S: ctx.args.id}
		}
	};
}
export function response(ctx) {
	if (ctx.error) {
		return util.error(ctx.error.message, ctx.error.type);
	}
	return ctx.result;
}
EOF
}
resource "aws_appsync_resolver" "Mutation_setImagePublicity" {
  api_id = aws_appsync_graphql_api.appsync.id
  type   = "Mutation"
  field  = "setImagePublicity"
  runtime {
    name            = "APPSYNC_JS"
    runtime_version = "1.0.0"
  }
  code = <<EOF
export function request(ctx) {
	return {};
}
export function response(ctx) {
	return ctx.result;
}
EOF
  kind = "PIPELINE"
  pipeline_config {
    functions = [
      aws_appsync_function.Mutation_setImagePublicity_1.function_id,
    ]
  }
}
resource "aws_appsync_function" "Mutation_setImagePublicity_1" {
  api_id      = aws_appsync_graphql_api.appsync.id
  data_source = aws_appsync_datasource.ddb_images.name
  name        = "Mutation_setImagePublicity_1"
  runtime {
    name            = "APPSYNC_JS"
    runtime_version = "1.0.0"
  }
  code = <<EOF
import {util} from "@aws-appsync/utils";
export function request(ctx) {
	return {
		version : "2018-05-29",
		operation : "UpdateItem",
		key: {
			key: {S: ctx.args.key},
		},
		update: {
			expression: "SET #public = :public, #useridPublic = :useridPublic",
			expressionNames: {
				"#public": "public",
				"#useridPublic": "userid#public",
			},
			expressionValues: {
				":public": {BOOL: ctx.args.public},
				":useridPublic": {S: ctx.identity.sub + "#" + ctx.args.public},
			},
		},
		condition: {
			expression: "attribute_exists(#pk) AND #userid = :userid",
			expressionNames: {
				"#pk": "key",
				"#userid": "userid",
			},
			expressionValues: {
				":userid": {S: ctx.identity.sub},
			},
		}
	};
}
export function response(ctx) {
	if (ctx.error) {
		return util.error(ctx.error.message, ctx.error.type);
	}
	return ctx.result;
}
EOF
}

resource "aws_appsync_resolver" "Mutation_addImage" {
  api_id = aws_appsync_graphql_api.appsync.id
  type   = "Mutation"
  field  = "addImage"
  runtime {
    name            = "APPSYNC_JS"
    runtime_version = "1.0.0"
  }
  code = <<EOF
export function request(ctx) {
	return {};
}
export function response(ctx) {
	return ctx.result;
}
EOF
  kind = "PIPELINE"
  pipeline_config {
    functions = [
      aws_appsync_function.Mutation_addImage_1.function_id,
    ]
  }
}
resource "aws_appsync_function" "Mutation_addImage_1" {
  api_id      = aws_appsync_graphql_api.appsync.id
  data_source = aws_appsync_datasource.lambda_image_uploader.name
  name        = "Mutation_addImage_1"
  runtime {
    name            = "APPSYNC_JS"
    runtime_version = "1.0.0"
  }
  code = <<EOF
import {util} from "@aws-appsync/utils";
export function request(ctx) {
	return {
		version: "2018-05-29",
		operation: "Invoke",
		payload: {
			key: ctx.args.key,
			userid: ctx.identity.sub,
		}
	};
}
export function response(ctx) {
	if (ctx.error) {
		return util.error(ctx.error.message, ctx.error.type);
	}
	return ctx.result;
}
EOF
}
