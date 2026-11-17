import Link from 'next/link';

// not-found cannot read the route's locale, so it speaks both languages.
export default function NotFound() {
  return (
    <main className="page">
      <section className="home">
        <h1 className="title">갤러리를 찾을 수 없어요</h1>
        <p className="bio">주소를 다시 확인해 주세요. 비공개로 바뀐 갤러리일 수도 있어요.</p>
        <p className="meta" lang="en">Gallery not found. Check the address; it may also have been made private.</p>
        <p>
          <Link className="btn" href="/">처음으로 · Home</Link>
        </p>
      </section>
    </main>
  );
}
