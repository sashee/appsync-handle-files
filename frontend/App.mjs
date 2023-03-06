import usePromise from "react-use-promise";
import htm from "htm";
import React, {useState} from "react";

const html = htm.bind(React.createElement);

const makePaginatedFetcher = (sendQuery, processItem, fieldNames) => (...args) => async (currentPage = undefined, previousPages = []) => {
	const [currentItems, nextItems] = await Promise.all([
		(async () => {
			return {
				...currentPage,
				[fieldNames.items]: currentPage ? await Promise.all(currentPage[fieldNames.items].map(processItem)) : [],
			}
		})(),
		(async () => {
			if (!currentPage || currentPage[fieldNames.nextToken]) {
				const nextPage = await sendQuery(currentPage?.[fieldNames.nextToken], previousPages, ...args);
				if (nextPage) {
					return makePaginatedFetcher(sendQuery, processItem, fieldNames)(...args)(nextPage, [...previousPages, nextPage[fieldNames.items]]);
				}
			}
		})(),
	]);
	return {
		...currentItems,
		[fieldNames.items]: [...(currentItems[fieldNames.items] ?? []), ...(nextItems?.[fieldNames.items] ?? [])],
		[fieldNames.nextToken]: nextItems ? nextItems[fieldNames.nextToken] : currentItems[fieldNames.nextToken],
	}
}

const sendAppSyncQuery = (APIURL, getAccessToken) => async (query, variables) => {
	const url = new URL(APIURL);
	const res = await fetch(APIURL, {
		method: "POST",
		body: JSON.stringify({
			query,
			operationName: "MyQuery",
			variables,
		}),
		headers: {
			"Content-Type": "application/graphql",
			host: url.hostname,
			Authorization: await getAccessToken(),
		},
	});
	if (!res.ok) {
		throw new Error("Failed");
	}
	const resJson = await res.json();
	if (resJson.errors) {
		throw new Error(JSON.stringify(resJson));
	}
	return resJson.data;
};

export const App = ({APIURL, loggedin, getAccessToken, redirectToLogin, redirectToLogout}) => {
	const query = sendAppSyncQuery(APIURL, getAccessToken);
	const [changedImages, setChangedImages] = useState([]);
	const [items, loadError, loadState] = usePromise(async () => {
		if(loggedin) {
			const imagesSubquery = `
				images {
					key
					url
					public
				}
				nextToken
			`;

			const fetchImages = makePaginatedFetcher(async (nextToken, _previousPages, userid) => {
				return (await query(`
					query MyQuery($id: ID!, $nextToken: String) {
						user(id: $id) {
							images(nextToken: $nextToken) {
								${imagesSubquery}
							}
						}
					}
				`, {id: userid, nextToken})).user.images;
			}, (image) => image, {items: "images", nextToken: "nextToken"})

			const fetchUsers = makePaginatedFetcher(async (nextToken) => {
				return (await query(`
					query MyQuery($nextToken: String) {
						allUsers(nextToken: $nextToken) {
							users {
								username
								id
								images {
									${imagesSubquery}
								}
							}
							nextToken
						}
					}
				`, {nextToken})).allUsers;
			}, async (user) => {
				return {
					...user,
					images: await fetchImages(user.id)(user.images),
				};
			}, {items: "users", nextToken: "nextToken"});

			const [currentUser, users] = await Promise.all([
				query(`
					query MyQuery {
						currentUser {
							username
							id
						}
					}
				`, {}),
				await fetchUsers()(),
			]);
			return {currentUser: currentUser.currentUser, users: users.users};
		}
	}, []);

	const changeVisibility = async (userid, key, desiredPublic) => {
		const currentImage = changedImages.find((image) => image.key === key) ?? items.users.find(({id}) => id === userid).images.images.find((image) => image.key === key);
		setChangedImages([...changedImages.filter((image) => image.key !== key), {...currentImage, publicChanging: true}]);
		const res = await query(`
			mutation MyQuery($key: ID!, $public: Boolean!) {
				setImagePublicity(key: $key, public: $public) {
					key
					url
					public
				}
			}
				`, {key, public: desiredPublic});
		setChangedImages([...changedImages.filter((image) => image.key !== key), res.setImagePublicity]);
	};

	const uploadFiles = async (files) => {
		const ids = files.map(() => crypto.randomUUID());
		setChangedImages([...files.map((_file, idx) => ({public: false, uploading: true, uploadId: ids[idx]})), ...changedImages]);
		const uploadedImages = await Promise.all(files.map(async (file) => {
			const query = sendAppSyncQuery(APIURL, getAccessToken);
			const uploadData = JSON.parse((await query(`
				query MyQuery {
					getUploadURL
				}
			`, {})).getUploadURL);

			const formData = new FormData();

			// content type
			formData.append("Content-Type", file.type);
			// data.fields
			Object.entries(uploadData.fields).forEach(([k, v]) => {
				formData.append(k, v);
			});
			// file
			formData.append("file", file); // must be the last one

			// send it
			const postRes = await fetch(uploadData.url, {
				method: "POST",
				body: formData,
			});

			if (!postRes.ok) {
				throw postRes;
			}
			const addedImage = (await query(`
				mutation MyQuery($key: ID!) {
					addImage(key: $key) {
						key
						url
						public
					}
				}
			`, {key: uploadData.fields["x-amz-key"]})).addImage;
			return addedImage;
		}));
		setChangedImages((changedImages) => {
			return changedImages.map((image) => {
				const matchingUploadedImageIndex = ids.findIndex((id) => image.uploadId === id);
				if (matchingUploadedImageIndex > -1) {
					return uploadedImages[matchingUploadedImageIndex];
				}else {
					return image;
				}
			});
		});
	}

	return html`
		<div class="container">
			<ul class="nav justify-content-end mb-5">
				<li class="nav-item">
					<a class="nav-link disabled">${loggedin ? "Logged in" : "Not logged in"}</a>
				</li>
				<li class="nav-item">
					${loggedin ?
						html`<a class="nav-link" href="#" onClick=${redirectToLogout}>Logout</a>`
						: html`<a class="nav-link" href="#" onClick=${redirectToLogin}>Login</a>`
					}
				</li>
			</ul>
			${!loggedin && html`
				<div>
					<h1>Welcome to this example project!</h1>
					<p>To view and upload images <a href="#" onClick=${redirectToLogin}>log in</a> with one of the user:
						<ul>
							<li>user1 // Password.1</li>
							<li>user2 // Password.1</li>
						</ul>
					</p>
					<p>Then you can browse the uploaded images, upload new ones, and define the visiblity of the active user's images</p>
				</div>
			`}
			${loadError ? html`
				<pre>
					${loadError}
				</pre>
			` : ""}
			${loadState === "pending" ? html`<div class="text-center my-5"><div class="spinner-border" role="status"/></div>` : ""}
			${items ? [...items.users].sort((a, b) => a.id === items.currentUser.id ? -1 : b.id === items.currentUser.id ? 1 : 0).map((user) => html`
				<${UserImagesBox}
					user=${user}
					ownUser=${user.id === items.currentUser.id}
					changeVisibility=${changeVisibility}
					uploadFiles=${uploadFiles}
					changedImages=${changedImages}
				/>
			`) : ""}
		</div>`;
};

export const UserImagesBox = ({user, ownUser, changeVisibility, uploadFiles, changedImages}) => {
	const newImages = ownUser ? changedImages.filter((img) => img.uploading || !user.images.images.some((image) => img.key === image.key)) : [];
	const handleFile = (event) => {
		uploadFiles([...event.target.files]);
		event.target.value = null;
	}
	return html`
		<div class="user-box container mb-5">
			<div class="my-4 d-flex align-items-center">
				<span class="font-monospace h3 my-0">${user.username}'s ${!ownUser && "public "}photos</span>
				${ownUser && html` <span class="badge bg-info align-middle font-monospace h3 ms-2 my-0">Current user</span>`}
				${ownUser && html`
					<label class="btn btn-outline-secondary ms-5">
						<input type="file" class="d-none" accept="image/*" onChange=${handleFile}/>
						Upload image
					</label>
				`}
			</div>
			<div class="row">
				${[...newImages,
					...user.images.images.map((image) => {
						return changedImages.find(({key}) => key === image.key) ?? image;
				})].map((image, idx) => html`
					<div key=${image.key ?? idx} class="col-lg-4 col-md-6 d-flex flex-column justify-content-between my-3">
						<img src=${image.uploading ? "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsQAAA7EAZUrDhsAAAANSURBVBhXYzh8+PB/AAffA0nNPuCLAAAAAElFTkSuQmCC" : image.url} class="img-thumbnail flex-grow-1"/>
						${ownUser && html`
							<label class="toggle text-center pt-2">
								<input class="toggle-checkbox" type="checkbox" checked=${image.public} disabled=${image.uploading || image.publicChanging} onChange=${() => changeVisibility(user.id, image.key, !image.public)}></input>
								<div class="toggle-switch"></div>
								<span class="toggle-label">Public</span>
							</label>
						`}
					</div>
				`)}
			</div>
		</div>
	`
};
