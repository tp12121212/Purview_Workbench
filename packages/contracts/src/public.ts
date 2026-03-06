export type PublicLibraryItem = {
  id: string;
  title: string;
  summary: string;
  category: 'SIT' | 'DLP';
};

export type PublicAppMetadata = {
  productName: string;
  docsUrl: string;
  supportEmail: string;
};
