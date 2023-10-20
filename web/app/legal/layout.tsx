export default function LegalLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <div className="px-8 py-10 m-auto prose lg:prose-xl dark:prose-invert">
      {children}
    </div>
  );
}
